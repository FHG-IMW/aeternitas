require "rails/generators"
require "rails/generators/active_record"

module Aeternitas
  # Installs Aeternitas in a rails app.
  class InstallGenerator < ::Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path("../templates", __FILE__)

    desc 'Generates (but does not run) a migration to add all tables needed by Aeternitas.' \
         '  Also generates an initializer file for configuring Aeternitas'

    def create_migration_file
      migration_dir = File.expand_path("db/migrate")
      if self.class.migration_exists?(migration_dir, template)
        ::Kernel.warn "Migration already exists: #{template}"
      else
        migration_template('add_aeternitas.rb.erb', 'db/migrate/add_aeternitas.rb')
      end
    end

    def copy_initializer
      copy_file('initializer.rb', 'config/initializers/aeternitas.rb')
    end

    def reminder
      say "Don't forget to regularly run 'Aeternitas.enqueue_due_pollables'. E.g using 'whenever'", :yellow
    end

    def self.next_migration_number(dirname)
      ::ActiveRecord::Generators::Base.next_migration_number(dirname)
    end
  end
end