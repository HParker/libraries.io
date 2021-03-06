class GithubUser < ApplicationRecord
  include Profile

  has_many :github_contributions, dependent: :delete_all
  has_many :github_repositories, primary_key: :github_id, foreign_key: :owner_id
  has_many :source_github_repositories, -> { where fork: false }, anonymous_class: GithubRepository, primary_key: :github_id, foreign_key: :owner_id
  has_many :open_source_github_repositories, -> { where fork: false, private: false }, anonymous_class: GithubRepository, primary_key: :github_id, foreign_key: :owner_id
  has_many :dependencies, through: :open_source_github_repositories
  has_many :favourite_projects, -> { group('projects.id').order("COUNT(projects.id) DESC") }, through: :dependencies, source: :project
  has_many :contributed_repositories, -> { GithubRepository.source.open_source }, through: :github_contributions, source: :github_repository
  has_many :contributors, -> { group('github_users.id').order("sum(github_contributions.count) DESC") }, through: :open_source_github_repositories, source: :contributors
  has_many :fellow_contributors, -> (object){ where.not(id: object.id).group('github_users.id').order("COUNT(github_users.id) DESC") }, through: :contributed_repositories, source: :contributors
  has_many :projects, through: :open_source_github_repositories

  has_many :github_issues, primary_key: :github_id

  validates :login, uniqueness: true, if: lambda { self.login_changed? }
  validates :github_id, uniqueness: true, if: lambda { self.github_id_changed? }

  after_commit :async_sync, on: :create

  scope :visible, -> { where(hidden: false) }

  def meta_tags
    {
      title: "#{self} on GitHub",
      description: "GitHub repositories created and contributed to by #{self}",
      image: avatar_url(200)
    }
  end

  def open_source_contributions
    github_contributions.joins(:github_repository).where("github_repositories.fork = ? AND github_repositories.private = ?", false, false)
  end

  def org?
    false
  end

  def description
    nil
  end

  def github_client
    AuthToken.client
  end

  def async_sync
    GithubUpdateUserWorker.perform_async(self.login)
  end

  def sync
    download_from_github
    download_orgs
    download_repos
    update_attributes(last_synced_at: Time.now)
  end

  def download_from_github
    update_attributes(github_client.user(github_id).to_hash.slice(:login, :name, :company, :blog, :location, :email, :bio, :followers, :following))
  rescue *GithubRepository::IGNORABLE_GITHUB_EXCEPTIONS
    nil
  end

  def download_orgs
    github_client.orgs(login).each do |org|
      GithubCreateOrgWorker.perform_async(org.login)
    end
    true
  rescue *GithubRepository::IGNORABLE_GITHUB_EXCEPTIONS
    nil
  end

  def download_repos
    AuthToken.client.search_repos("user:#{login}").items.each do |repo|
      GithubRepository.create_from_hash repo.to_hash
    end

    true
  rescue *GithubRepository::IGNORABLE_GITHUB_EXCEPTIONS
    nil
  end
end
