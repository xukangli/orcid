require 'rest_client'
class RequestSandboxAuthorizationCode

  def self.call(options = {}, config = {})
    new(config).call(options)
  end

  attr_reader :cookies, :access_scope, :authorize_url, :login_url
  attr_reader :oauth_redirect_uri, :orcid_client_id, :authorization_code, :orcid_client_secret

  def initialize(options = {})
    @orcid_client_id = options.fetch(:orcid_client_id) { Orcid.provider.id }
    @orcid_client_secret = options.fetch(:orcid_client_secret) { Orcid.provider.secret }
    @login_url = options.fetch(:login_url) { Orcid.provider.signin_via_json_url }
    @authorize_url = options.fetch(:authorize_url) { Orcid.provider.authorize_url }
    @oauth_redirect_uri = options.fetch(:oauth_redirect_uri) { 'https://developers.google.com/oauthplayground' }
    @access_scope = options.fetch(:scope) { Orcid.provider.authentication_scope }
  end

  def call(options = {})
    orcid_profile_id = options.fetch(:orcid_profile_id) { ENV['ORCID_CLAIMED_PROFILE_ID'] }
    password = options.fetch(:password) { ENV['ORCID_CLAIMED_PROFILE_PASSWORD'] }

    login_to_orcid(orcid_profile_id, password)
    request_authorization
    request_authorization_code
  end

  attr_writer :cookies
  private :cookies

  private

  def login_to_orcid(orcid_profile_id, password)
    response = RestClient.post(
      login_url, userId: orcid_profile_id, password: password
    )
    if JSON.parse(response)['success']
      self.cookies = response.cookies
    else
      fail "Response not successful: \n#{response}"
    end
  end

  def request_authorization
    parameters = {
      client_id: orcid_client_id,
      response_type: 'code',
      scope: access_scope,
      redirect_uri: oauth_redirect_uri
    }
    RestClient.get(authorize_url, { params: parameters, cookies: cookies })
  end

  def request_authorization_code
    RestClient.post(
      authorize_url, { user_oauth_approval: true }, { cookies: cookies }
    )
  rescue RestClient::Found => e
    uri = URI.parse(e.response.headers.fetch(:location))
    CGI.parse(uri.query).fetch('code').first
  end

end
