module ShellTest
  module EnvMethods
    module_function

    # Sets the specified ENV variables and returns the *current* env.
    # If replace is true, current ENV variables are replaced; otherwise
    # the new env variables are simply added to the existing set.
    def set_env(env={}, replace=false)
      current_env = {}
      ENV.each_pair do |key, value|
        current_env[key] = value
      end

      ENV.clear if replace

      env.each_pair do |key, value|
        if value.nil?
          ENV.delete(key)
        else
          ENV[key] = value
        end
      end if env

      current_env
    end

    # Sets the specified ENV variables for the duration of the block.
    # If replace is true, current ENV variables are replaced; otherwise
    # the new env variables are simply added to the existing set.
    #
    # Returns the block return.
    def with_env(env={}, replace=false)
      current_env = nil
      begin
        current_env = set_env(env, replace)
        yield
      ensure
        if current_env
          set_env(current_env, true)
        end
      end
    end
  end
end