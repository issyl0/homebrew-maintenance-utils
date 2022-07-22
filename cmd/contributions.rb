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
        description: "A user's email address that they commit with (useful if not public on GitHub)."

      flag "--before=",
        description: "Date (ISO-8601 format) to search contributions prior to a date."

      flag "--after=",
        description: "Date (ISO-8601 format) to search contributions after a date."

      flag "--repo=",
        description: "The Homebrew repository to search for contributions in (brew, core, cask, bundle, ...)."

      switch "--only-direct-authorship",
        description: "Only count commits that the user directly authored."

      switch "--only-coauthorship",
        description: "Only count commits that the user co-authored."

      conflicts "--username", "--email"
      named_args max: 0
    end
  end

  def contributions
    args = contributions_args.parse

    repo_location = find_repo_path_for_repo(args[:repo])
    unless repo_location
      ofail "Couldn't find location for #{args[:repo]}. Is there a typo? We only support brew, core, cask, and bundle repos so far."
      return
    end

    commits = `git -C #{repo_location} log --oneline --author=#{args[:username] || args[:email]}  | wc -l`.strip.to_i
    coauthorships = `git -C #{repo_location} log --oneline --format="%(trailers:key=Co-authored-by:)" | grep #{args[:username] || args[:email]} | wc -l`.strip.to_i

    puts "Person #{args[:username] || args[:email]} directly authored #{commits} commits and co-authored #{coauthorships} commits to #{args[:repo]} in all time."
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
end
