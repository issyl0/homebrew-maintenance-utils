# frozen_string_literal: true

require "cli/parser"
require "formula"
require "utils/github"
require "utils/inreplace"

module Homebrew
  module_function

  def find_invalid_head_branches_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `find-invalid-head-branches`
        Find formulae whose specified HEAD branch doesn't exist on the remote repo.
      EOS

      switch "--fix",
             description: "Fix the HEAD line in the formula to point to the new branch."

      named_args max: 0
    end
  end

  def find_invalid_head_branches
    odie "Set the `HOMEBREW_GITHUB_API_TOKEN envvar." if ENV["HOMEBREW_GITHUB_API_TOKEN"].blank?

    args = find_invalid_head_branches_args.parse

    head_formulae.each do |formula|
      # TODO: Support GitLab and other code hosts.
      next unless formula.head.url.include?("github.com")

      formula_head_branch = formula.head.specs[:branch]
      next if formula_head_branch.nil? # Lots of `head do` blocks have `nil` branch data.

      odebug "Scanning #{formula.name}..."
      user, repo = parse_repo_url(formula.head.url)
      next if user == "github" # My access token can't access even public `github` org repos without SSO.

      remote_default_branch = GitHub.repository(user, repo)["default_branch"]
      next if formula_head_branch == remote_default_branch

      # A branch is still valid if it exists on the repo but is not the default.
      next if GitHub.branch_exists?(user, repo, formula_head_branch)

      opoo "#{formula.name}: #{formula_head_branch} => #{remote_default_branch}"
      next unless args.fix?

      opoo "Fixing #{formula.name}..."
      Utils::Inreplace.inreplace(formula.path) do |s|
        s.gsub!("branch: \"#{formula_head_branch}\"", "branch: \"#{remote_default_branch}\"")
      end
    end
  end

  def head_formulae
    Formula.all.reject { |f| f.head.nil? }
  end

  def parse_repo_url(url)
    url.gsub("https://", "").gsub("github.com/", "").gsub(".git", "").split("/")
  end
end
