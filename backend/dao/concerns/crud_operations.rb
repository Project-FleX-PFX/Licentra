module CrudOperations

    module ClassMethods
  
      # --- CREATE ---
      def create(attributes)
        context = "creating #{model_class_name}"
        with_error_handling(context) do
          instance = model_class.new(attributes)
          if instance.valid?
            instance.save
            log_created(instance)
            instance
          else
            handle_validation_error(instance, context)
          end
        end
      end
  
      # --- READ ---
      def find!(id)
         context = "finding #{model_class_name} with #{primary_key} #{id}"
         with_error_handling(context) do
           instance = find_by_pk_helper(id)
           unless instance
             handle_record_not_found(id)
           end
           log_found(instance)
           instance
         end
       end
  
       def find(id)
         context = "finding #{model_class_name} with #{primary_key} #{id}"
         with_error_handling(context) do
           instance = find_by_pk_helper(id)
           log_found(instance) if instance
           instance
         end
       end
  
       def find_one_by(criteria)
         context = "finding #{model_class_name} by criteria"
         with_error_handling(context) do
           instance = model_class.first(criteria)
           log_found_by_criteria(criteria, instance) if instance
           instance
         end
       end
  
       def find_one_by!(criteria)
         context = "finding #{model_class_name} by criteria"
         with_error_handling(context) do
           instance = find_one_by(criteria)
           unless instance
              handle_record_not_found_by_criteria(criteria)
           end
           instance
         end
       end
  
       def all(options = {})
         context = "fetching all #{model_class_name_plural}"
         with_error_handling(context) do
           dataset = model_class.dataset
           dataset = dataset.where(options[:where]) if options[:where]
           dataset = dataset.order(options[:order]) if options[:order]
           instances = dataset.all
           log_fetched(instances.size)
           instances
         end
       end
  
       def where(criteria)
         context = "filtering #{model_class_name_plural} by criteria"
         with_error_handling(context) do
           instances = model_class.where(criteria).all
           log_fetched_with_criteria(instances.size, criteria)
           instances
         end
       end
  
  
      # --- UPDATE ---
      def update(id, attributes)
        context = "updating #{model_class_name} with #{primary_key} #{id}"
        with_error_handling(context) do
          instance = find_by_pk_helper(id)
          unless instance
             handle_record_not_found(id)
          end
          begin
            instance.update(attributes)
            log_updated(instance)
            instance
          rescue Sequel::ValidationFailed => e
            handle_validation_error(e.model, context)
          end
        end
      end
  
      # --- DELETE ---
      def delete(id)
        context = "deleting #{model_class_name} with #{primary_key} #{id}"
        with_error_handling(context) do
          instance = find_by_pk_helper(id)
          unless instance
             handle_record_not_found(id)
          end
          instance.destroy
          log_deleted(instance)
          true
        end
      end
  
      private
  
      def find_by_pk_helper(id)
          self.model_class[self.primary_key => id]
      end
  
      def model_class_name
         self.model_class.name.gsub(/([A-Z])/, ' \1').strip.downcase
      end
  
      def model_class_name_plural
          name = model_class_name
          name.end_with?('s') ? name : "#{name}s"
      end
  
    end
  
    def self.included(base)
      base.extend(ClassMethods)
    end
  
end
