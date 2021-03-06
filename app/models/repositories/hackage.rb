module Repositories
  class Hackage < Base
    HAS_VERSIONS = true
    HAS_DEPENDENCIES = false
    LIBRARIAN_PLANNED = true
    URL = 'http://hackage.haskell.org'
    COLOR = '#29b544'

    def self.project_names
      get_json("http://hackage.haskell.org/packages/").map{ |h| h['packageName'] }
    end

    def self.recent_names
      u = 'http://hackage.haskell.org/packages/recent.rss'
      titles = SimpleRSS.parse(get_raw(u)).items.map(&:title)
      titles.map { |t| t.split(' ').first }
    end

    def self.project(name)
      {
        name: name,
        page: get_html("http://hackage.haskell.org/package/#{name}")
      }
    end

    def self.mapping(project)
      {
        name: project[:name],
        keywords_array: Array(project[:page].css('#content div:first a')[1..-1].map(&:text)),
        description: description(project[:page]),
        licenses: find_attribute(project[:page], 'License'),
        homepage: find_attribute(project[:page], 'Home page'),
        repository_url: repo_fallback(repository_url(find_attribute(project[:page], 'Source repository')), find_attribute(project[:page], 'Home page'))
      }
    end

    def self.versions(project)
      versions = find_attribute(project[:page], 'Versions')
      versions = find_attribute(project[:page], 'Version') if versions.nil?
      versions.split(',').map(&:strip).map do |v|
        {
          :number => v
        }
      end
    end

    def self.find_attribute(page, name)
      tr = page.css('#content tr').select { |t| t.css('th').text == name }.first
      tr.css('td').text if tr
    end

    def self.description(page)
      contents = page.css('#content p, #content hr' ).map(&:text)
      index = contents.index ''
      contents[0..(index - 1)].join("\n\n")
    end

    def self.repository_url(text)
      return nil unless text.present?
      match = text.match(/github.com\/(.+?)\.git/)
      return nil unless match
      "https://github.com/#{match[1]}"
    end
  end
end
