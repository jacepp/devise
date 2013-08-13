# require 'orm_adapter/adapters/ripple'

# Ripple::Document::ClassMethods.send :include, Devise::Models

module Devise
  module Orm
    module Ripple
      module Hook
        def devise_modules_hook!
          include ::Ripple::Timestamps
          include Compatibility
          yield
          devise_modules.each { |m| send(m) if respond_to?(m, true) }
        end
      end

      module Compatibility
        extend ActiveSupport::Concern

        module ClassMethods

          def validates_uniqueness_of(*args)
            # no-op right now
          end

          def find(*args)

            # TODO from new Riak release start using provided Riak.mapByFields
            def user_id_from_conditions(conditions)

              map = "
                function(v) {
                  if (v.values) {
                    var v = Riak.mapValuesJson(v)[0];
                    return (#{conditions.map { |k,v| "v.#{k} === '#{v}'" }.join(' && ')}) ? [v.email] : [];
                  } else return [];
                }
              "

              uid = Riak::MapReduce.new(bucket.client).add(bucket).map(map, :keep => true).run

            end

            case args.length
            when 1 then
              super(args[0])
            when 2 then
              cs = args[1][:conditions]
              if cs.include? :email or cs.include? :id
                super(cs[:email] || cs[:id])
              else
                uid = user_id_from_conditions(cs)
                super(uid.first) unless uid.empty?
              end
            else
              raise RuntimeError, "[devise-ripple] Giving up: didn't expect #{args.length} arguments!"
            end

          end

        end

      end
    end
  end
end

Ripple::Document::ClassMethods.class_eval do
  include Devise::Models
  include Devise::Orm::Ripple::Hook
end