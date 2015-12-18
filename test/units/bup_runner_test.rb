#!/usr/bin/env ruby
require_relative  "test_helper"
require 'bup_runner'
include BupRunner
require 'byebug'

class BupRunnerTest < Minitest::Test
    context 'a BackupTarget' do
        setup do
            @target = BackupTarget.new( Pathname.pwd + 'test/res' )
        end

        should 'auto setup name from path' do
            assert_equal 'res', @target.name
        end

        should 'allow change name' do
            @target.name 'myhome'
            assert_equal 'myhome', @target.name
        end
        
        should 'auto set strip_path as path' do
            assert_equal @target.strip_path, @target.path
        end

        should 'allow change strip_path' do
            @target.strip_path "/tmp"
            assert_equal '/tmp', @target.strip_path.to_s
        end


        should 'allow add one path to exclude_paths' do
            @target.exclude_path "a.txt"
            assert_equal ['a.txt'], @target.exclude_path

            @target.exclude_path "b.txt" 
            assert_equal ['a.txt', 'b.txt'], @target.exclude_path
        end

        should 'allow add path array to exclude_paths' do
            @target.exclude_path ["d.txt", "c.txt", "b.txt", 'a.txt' ] 
            assert_equal ['a.txt', 'b.txt', 'c.txt', 'd.txt' ], @target.exclude_path
        end
    end

    context 'a BackupRepo' do
        setup do
            @repo = BackupRepo.new( "#{Dir.getwd}/tmp/backup_root", "repo" ) 
        end

        should 'detect volume attached' do
            #Simulate not attached
            FileUtils.rm_rf "#{Dir.getwd}/tmp/backup_root"
            assert !@repo.attached?
            assert !@repo.init?

            #Simulate volume attached but not init
            FileUtils.mkdir_p "#{Dir.getwd}/tmp/backup_root"
            assert @repo.attached?
            assert !@repo.init?

            #Simulate volume attached and @repo init
            FileUtils.mkdir_p "#{Dir.getwd}/tmp/backup_root/repo"
            assert @repo.attached?
            assert @repo.init?
        end
    end

    context 'a BackupConfig' do
        setup do
            @config = BackupConfig.new
        end

        should 'allow add target' do
            @config.target( "/a" ) do
                name "newname"
            end

            @config.target( "/b" ) do
            end

            assert_equal 2, @config.targets.length
            assert_equal "newname", @config.targets["/a"].name
            assert_equal "b", @config.targets["/b"].name
        end

        should 'allow add repo' do
            @config.repo( "/usr/lib", "a" )

            path = "/usr/lib/a"
            assert @config.repos[path]
            assert_equal Pathname.new(path), @config.repos[path].path
        end

        should 'select exist repo' do
            @config.repo( "/usr/lib", "a" )
            @config.repo( "/usr/lib2", "a" )
            assert @config.select_repo
            assert_equal Pathname.new("/usr/lib/a"), @config.select_repo.path

        end

        should 'report error  when select_repo and two repo exists' do
            @config.repo( "/usr/lib", "a" )
            @config.repo( "/usr/bin", "c" )

            ex = assert_raises{ @config.select_repo }
            assert_match /^Error: More.*/, ex.message
        end

        should 'report error  when select_repo and no repo exists' do
            @config.repo( "/usr/lib2", "a" )
            @config.repo( "/usr/bin2", "c" )

            ex = assert_raises{ @config.select_repo }
            assert_match /^Error: No.*/, ex.message
        end
    end

    context 'a BupDriver' do
        setup do
            @target = BackupTarget.new( "/home/yangchen" )
            @repo = BackupRepo.new( "/media/yangchen", "repo" )
            @driver = BupDriver.new( @repo, @target )
            @driver.dry_run = true
        end

        should 'raise error when two backup device avaliable' do
        end

        should "call init when index" do
            @driver.expects(:run).with("bup init")
            @driver.expects(:run).with("bup index -f /media/yangchen/repo/yangchen.index -uxpm  /home/yangchen")
            @driver.index
            assert_equal @repo.path.to_s, ENV["BUP_DIR"]
        end

        should "call init when save" do
            @driver.verbose(true)
            @driver.expects(:run).with("bup init")
            @driver.expects(:run).with("bup save -f /media/yangchen/repo/yangchen.index --strip-path /home/yangchen -n yangchen /home/yangchen")
            @driver.save
            assert_equal @repo.path.to_s, ENV["BUP_DIR"]
        end

        should "generate exclude_file for exclude" do
            paths = ["/a", "/b", "/c"]
            @target.exclude_path paths
            #@driver.verbose(true)
            FileUtils.rm_rf @driver.exclude_file
            @driver.index
            assert_equal paths, @driver.exclude_file.read.split("\n")
        end

        should "add target path as prefix to exclude path if it is relative" do
            paths = ["a", "b", "c"]
            @target.exclude_path paths
            #@driver.verbose(true)
            FileUtils.rm_rf @driver.exclude_file
            @driver.index
            assert_equal paths.map{ |s| ( @target.path + s ).to_s }, @driver.exclude_file.read.split("\n")        end
    end
end
