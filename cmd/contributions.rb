# frozen_string_literal: true

module Homebrew
  module_function

  def contributions_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `contributions`
        Contributions to Homebrew repos for a user.
      EOS

      flag "--username=",
        description: "The GitHub username of the user whose contributions you want to find."

      flag "--email",
        description: "A user's email address that they commit with."

      flag "--from=",
        description: "Date (ISO-8601 format) to start searching contributions."

      flag "--to=",
        description: "Date (ISO-8601 format) to stop searching contributions."

      comma_array "--repos=",
        description: "The Homebrew repositories to search for contributions in. Comma separated. Supported repos: brew, core, cask, bundle."

      conflicts "--username", "--email"

      named_args :none
    end
  end

  def contributions
    args = contributions_args.parse

    if !args[:repos] && (args[:username] || args[:email])
      ofail "`--repos` and one of `--username` or `--email` are required."
      return
    end

    commits, coauthorships = {}, {}

    args[:repos].each do |repo|
      repo_location = find_repo_path_for_repo(repo)
      unless repo_location
        ofail "Couldn't find location for #{repo}. Is there a typo? We only support brew, core, cask, and bundle repos so far."
        return
      end

      commits[repo] = git_log_cmd("author", repo_location, args)
      coauthorships[repo] = git_log_cmd("coauthorships", repo_location, args)
    end

    sentence = "Person #{args[:username] || args[:email]} directly authored #{commits.values.sum} commits and co-authored #{coauthorships.values.sum} commits to #{args[:repos].join(", ")}"
    sentence += args[:from] && args[:to] ? " between #{args[:from]} and #{args[:to]}." : " in all time."

    puts sentence
  end

  def find_repo_path_for_repo(repo)
    case repo
    when "brew"
      HOMEBREW_REPOSITORY
    when "core"
      "#{HOMEBREW_REPOSITORY}/Library/Taps/homebrew/homebrew-core"
    when "cask"
      "#{HOMEBREW_REPOSITORY}/Library/Taps/homebrew/homebrew-cask"
    when "bundle"
      "#{HOMEBREW_REPOSITORY}/Library/Taps/homebrew/homebrew-bundle"
    end
  end

  def git_log_cmd(kind, repo_location, args)
    cmd = "git -C #{repo_location} log --oneline"
    cmd += " --author=#{args[:username] || args[:email]}" if kind == "author"
    cmd += " --format='%(trailers:key=Co-authored-by:)'" if kind == "coauthorships"
    cmd += " --before=#{args[:to]} --after=#{args[:from]}" if args[:from] && args[:to]
    cmd += " | grep #{args[:username] || args[:email]}" if kind == "coauthorships"

    `#{cmd} | wc -l`.strip.to_i
  end
end
