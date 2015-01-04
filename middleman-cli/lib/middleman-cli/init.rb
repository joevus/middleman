# CLI Module
module Middleman::Cli
  # A thor task for creating new projects
  class Init < Thor::Group
    include Thor::Actions

    check_unknown_options!

    argument :target, type: :string, default: '.'

    class_option 'template',
                 aliases: '-T',
                 default: 'middleman/middleman-templates-default',
                 desc: 'Use a project template'

    # Do not run bundle install
    class_option 'skip-bundle',
                 type: :boolean,
                 aliases: '-B',
                 default: false,
                 desc: 'Skip bundle install'

    # The init task
    def init
      require 'tmpdir'

      repo_path, repo_branch = if shortname?(options[:template])
        require 'open-uri'
        require 'json'

        api = 'http://directory.middlemanapp.com/api'
        uri = ::URI.parse("#{api}/#{options[:template]}.json")

        begin
          data = ::JSON.parse(uri.read)
          data['links']['github']
          data['links']['github'].split('#')
        rescue ::OpenURI::HTTPError
          say "Template `#{options[:template]}` not found in Middleman Directory."
          say 'Did you mean to use a full `user/repo` path?'
          exit
        end
      else
        repo_name, repo_branch = options[:template].split('#')
        [repository_path(repo_name), repo_branch]
      end

      Dir.mktmpdir do |dir|
        cmd = repo_branch ? "clone -b #{repo_branch}" : 'clone'

        run("git #{cmd} #{repo_path} #{dir}")

        inside(target) do
          thorfile = File.join(dir, 'Thorfile')

          if File.exist?(thorfile)
            ::Thor::Util.load_thorfile(thorfile)

            invoke 'middleman:generator'
          else
            source_paths << dir
            directory dir, '.', exclude_pattern: /\.git\/|\.gitignore$/
          end

          run('bundle install') unless ENV['TEST'] || options[:'skip-bundle']
        end
      end
    end

    protected

    def shortname?(repo)
      repo.split('/').length != 2
    end

    def repository_path(repo)
      "git://github.com/#{repo}.git"
    end

    # Add to CLI
    Base.register(self, 'init', 'init TARGET [options]', 'Create new project at TARGET')

    # Map "i", "new" and "n" to "init"
    Base.map(
      'i' => 'init',
      'new' => 'init',
      'n' => 'init'
    )
  end
end
