module Orcid
  # Responsible for:
  # * acknowledging that an ORCID Profile was requested
  # * submitting a request for an ORCID Profile
  # * handling the response for the ORCID Profile creation
  class ProfileRequest < ActiveRecord::Base
    def self.find_by_user(user)
      where(user: user).first
    end

    self.table_name = :orcid_profile_requests

    alias_attribute :email, :primary_email
    validates :user_id, presence: true, uniqueness: true
    validates :given_names, presence: true
    validates :family_name, presence: true
    validates :primary_email, presence: true, email: true, confirmation: true

    belongs_to :user

    def run(options = {})
      # Why dependency injection? Because this is going to be a plugin, and
      # things can't possibly be simple. I also found it easier to test the
      # #run method with these injected dependencies
      validator = options.fetch(:validator) { method(:validate_before_run) }
      return false unless validator.call(self)

      payload_xml_builder = options.fetch(:payload_xml_builder) do
        method(:xml_payload)
      end
      profile_creation_service = options.fetch(:profile_creation_service) do
        default_profile_creation_service
      end
      profile_creation_service.call(payload_xml_builder.call(attributes))
    end

    def default_profile_creation_service
      @default_profile_creation_service ||= begin
        Orcid::Remote::ProfileCreationService.new do |on|
          on.success do |orcid_profile_id|
            handle_profile_creation_response(orcid_profile_id)
          end
        end
      end
    end

    def validate_before_run(context = self)
      validate_profile_id_is_unassigned(context) &&
        validate_user_does_not_have_profile(context)
    end

    def validate_user_does_not_have_profile(context)
      user_orcid_profile = Orcid.profile_for(context.user)
      return true unless user_orcid_profile
      message = "#{context.class} ID=#{context.to_param}'s associated user" \
       " #{context.user.to_param} already has an assigned :orcid_profile_id" \
       " #{user_orcid_profile.to_param}"
      context.errors.add(:base, message)
      false
    end
    private :validate_user_does_not_have_profile

    def validate_profile_id_is_unassigned(context)
      return true unless context.orcid_profile_id?
      message = "#{context.class} ID=#{context.to_param} already has an" \
        " assigned :orcid_profile_id #{context.orcid_profile_id.inspect}"
      context.errors.add(:base, message)
      false
    end
    private :validate_profile_id_is_unassigned

    # NOTE: This one lies ->
    #   http://support.orcid.org/knowledgebase/articles/177522-create-an-id-technical-developer
    # NOTE: This one was true at 2014-02-06:14:55 ->
    #   http://support.orcid.org/knowledgebase/articles/162412-tutorial-create-a-new-record-using-curl
    def xml_payload(input = attributes)
      attrs = input.with_indifferent_access
      returning_value = <<-XML_TEMPLATE
      <?xml version="1.0" encoding="UTF-8"?>
      <orcid-message
      xmlns:xsi="http://www.orcid.org/ns/orcid https://raw.github.com/ORCID/ORCID-Source/master/orcid-model/src/main/resources/orcid-message-1.1.xsd"
      xmlns="http://www.orcid.org/ns/orcid">
      <message-version>1.1</message-version>
      <orcid-profile>
      <orcid-bio>
      <personal-details>
      <given-names>#{attrs.fetch('given_names')}</given-names>
      <family-name>#{attrs.fetch('family_name')}</family-name>
      </personal-details>
      <contact-details>
      <email primary="true">#{attrs.fetch('primary_email')}</email>
      </contact-details>
      </orcid-bio>
      </orcid-profile>
      </orcid-message>
      XML_TEMPLATE
      returning_value.strip
    end

    def handle_profile_creation_response(orcid_profile_id)
      self.class.transaction do
        update_column(:orcid_profile_id, orcid_profile_id)
        Orcid.connect_user_and_orcid_profile(user, orcid_profile_id)
      end
    end
  end
end
