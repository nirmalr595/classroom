# frozen_string_literal: true

module GitHubClassroom
  class LtiProvider
    attr_reader :consumer_key

    def initialize(consumer_key: nil, shared_secret: nil, redis_store: nil)
      @consumer_key = consumer_key
      @shared_secret = shared_secret
      @redis_store = redis_store
    end

    def self.construct_message(params)
      IMS::LTI::Models::Messages::Message.generate(params)
    end

    def launch_valid?(launch_request)
      lti_message = self.class.construct_message(launch_request.params)

      # duplicate nonce
      return false if nonce_exists?(lti_message.oauth_nonce)

      # nonce too old
      return false if DateTime.strptime(lti_message.oauth_timestamp, "%s") < 5.minutes.ago

      true
    end

    def save_message(lti_message)
      nonce = lti_message.oauth_nonce
      scoped = scoped_nonce(nonce)
      if @redis_store.set(scoped, lti_message.to_json)
        nonce
      else
        false
      end
    end

    def get_message(nonce)
      scoped = scoped_nonce(nonce)
      raw_message = @redis_store.get(scoped)

      raw_message.from_json
    end

    private

    def nonce_exists?(nonce)
      scoped = scoped_nonce(nonce)
      @redis_store.exists(scoped)
    end

    ##
    # Returns a nonce unique across LMSs
    def scoped_nonce(nonce)
      "#{@consumer_key}-#{nonce}"
    end
  end
end