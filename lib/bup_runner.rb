require 'fattr'
require 'pathname'
require 'byebug'

module BupRunner
    class BackupTarget
        fattr :path 
        fattr(:strip_path){ path }
        fattr(:name){ path.basename.to_s }

        alias_method :fattr_path, :path
        alias_method :fattr_name, :name
        alias_method :fattr_strip_path, :strip_path

        def path(v=nil)
            if v.nil?
                fattr_path
            else
                if v.is_a? Pathname
                    fattr_path v
                else
                    fattr_path Pathname.new(v)
                end
            end
        end

        def strip_path(v=nil)
            if v.nil?
                fattr_strip_path
            else
                if v.is_a? Pathname
                    fattr_strip_path v
                else
                    fattr_strip_path Pathname.new(v)
                end
            end
        end

        def initialize(path)
            if !path.is_a? Pathname
                self.path = Pathname.new( path )
            else
                self.path = path
            end

            @exclude_path = Set.new
        end

        def exclude_path(v=nil)
            if v.nil?
                @exclude_path.to_a.sort
            else
                if v.respond_to? :to_a
                   @exclude_path.merge( v.to_a )
                else
                    @exclude_path.add( v )
                end
            end
        end
    end

    class BackupRepo
        fattr :mount_path
        fattr :sub_path

        def path
            mount_point + sub_path
        end

        def mount_point
            Pathname.new( mount_path )
        end

        def attached?
           mount_point.directory? 
        end

        def init?
            path.exist? && path.directory?
        end

        def initialize( mount_path, sub_path )
            self.mount_path = mount_path
            self.sub_path = sub_path
        end
    end

    class BackupConfig
        attr_reader :targets, :repos
        def initialize
            @targets = {}
            @repos={}
        end

        def target(path=nil,&blk)
            t = targets[path]
            if t.nil?
                t = BackupTarget.new(path)
                targets[path] = t
            end

            if blk
                t.instance_eval &blk
            end
        end

        def repo(mount_path, sub_path,&blk)
            path = Pathname.new(mount_path) + sub_path
            t = repos[path]
            if t.nil?
                t = BackupRepo.new(path)
                repos[path] = t
            end

            if blk
                t.instance_eval &blk
            end
        end

        def self.load( config_file )
           self.new.instance_eval( config_file.open.read, config_file, 0 )
        end
    end

    class BupDriver
        attr_reader :target, :repo, :exclude_file
        
        fattr :dry_run => false
        fattr :verbose => false

        def initialize( target, repo )
            @target = target
            @repo = repo
            @exclude_file = Pathname.new( "#{ENV['HOME']}/tmp/bup_exclude_list" )
        end

        def path
            target.path
        end

        def strip_path
            target.strip_path
        end

        def index_path
            repo.path + "#{target.name}.index"
        end

        def name
            target.name
        end

        def init
            ENV["BUP_DIR"] = repo.path.to_s
            if @repo.attached? 
                if !@repo.init?
                    cmd = "bup init" 
                    run(cmd)
                end
            end
        end


        def exclude_opt
            if !target.exclude_path.empty?
                FileUtils.mkdir_p "#{ENV['HOME']}/tmp"
                @exclude_file.open("w") do |fd|
                    fd.write( target.exclude_path.join("\n") )
                end

                "--exclude_file=#{@exclude_file.to_s}"
            else
                ""
            end
        end

        def index
            init
            cmd = ( "bup index -f #{index_path} -uxpm #{exclude_opt} #{path}" )
            run( cmd )
        end

        def save
            init
            cmd = "bup save -f #{index_path} --strip-path #{strip_path} -n #{name} #{path}" 
            run( cmd )
        end

        def run(cmd)
            if verbose?
                puts cmd
            end
            if !dry_run?
                system(cmd)
            end
        end
    end
end
