module Orcid

  class ConfigurationError < RuntimeError
    def initialize(key_name)
      super("Unable to find #{key_name.inspect} in configuration storage.")
    end
  end

  # Because in trouble shooting what all goes into this remote call,
  # you may very well want all of this.
  class RemoteServiceError < RuntimeError
    def initialize(options)
      text = []
      text << "-- Client --"
      append_client_options(options[:client], text)
      append_token(options[:token], text)
      append_request(options, text)
      append_response(options, text)
      super(text.join("\n"))
    end

    private

    def append_client_options(client, text)
      if client
        text << "id:\n\t#{client.id.inspect}"
        text << "site:\n\t#{client.site.inspect}"
        text << "options:\n\t#{client.options.inspect}"
        if defined?(Orcid.provider)
          text << "scopes:\n\t#{Orcid.provider.authentication_scope}"
        end
      end
      text
    end

    def append_token(token, text)
      text << "\n-- Token --"
      if token
        text << "access_token:\n\t#{token.token.inspect}"
        text << "refresh_token:\n\t#{token.refresh_token.inspect}"
      end
      text
    end

    def append_request(options, text)
      text << "\n-- Request --"
      text << "path:\n\t#{options[:request_path].inspect}" if options[:request_path]
      text << "headers:\n\t#{options[:request_headers].inspect}" if options[:request_headers]
      text << "body:\n\t#{options[:request_body]}" if options[:request_body]
      text
    end

    def append_response(options, text)
      text << "\n-- Response --"
      text << "status:\n\t#{options[:response_status].inspect}" if options[:response_status]
      text << "body:\n\t#{options[:response_body]}" if options[:response_body]
      text
    end
  end
end
