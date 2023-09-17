class Brewery
  attr_accessor :name
  attr_accessor :website
  attr_accessor :beers
  attr_accessor :actual_location
  attr_accessor :festival_location

  def initialize(name, website, beers, actual_location, festival_location)
    @name = name
    @website = website
    @beers = beers
    @actual_location = actual_location
    @festival_location = festival_location
  end
end

class Beer
  attr_accessor :name
  attr_accessor :style
  attr_accessor :abv

  def initialize(name, style, abv)
    @name = name
    @style = style
    @abv = abv
  end
end

class ActualLocation
  attr_accessor :city
  attr_accessor :state
  attr_accessor :country
  attr_accessor :region

  def initialize(city, state, country, region)
    @city = city
    @state = state
    @country = country
    @region = region
  end
end

class FestivalLocation
  attr_accessor :island
  attr_accessor :booth
  attr_accessor :additional_taprooms

  def initialize(island, booth, additional_taprooms)
    @island = island
    @booth = booth
    @additional_taprooms = additional_taprooms
  end
end

def parse_breweries(breweries_json)
  breweries = []

  breweries_json.each do |brewery_json|
    brewery_name = brewery_json['company']
    registration_status = brewery_json['registrationstatus']
    website = brewery_json['website']

    breweries_without_beers = [
      '12 West Brewing',
    ]

    if brewery_name.nil? || breweries_without_beers.include?(brewery_name)
      # Some breweries have invalid data
      next
    end

    if registration_status != 'Confirmed'
      # Only include breweries that are confirmed for this year
      next
    end

    beers = parse_beers(brewery_json)

    if (
      beers.size < 1 && 
      # It's probably safe to skip these breweries
      !['Competition Badges', 'Judges', 'Volunteer Captains', 'Paired Staff'].include?(brewery_json['category_reportname'])
    )
      raise ArgumentError, "No beers #{brewery_json}" 
    end

    actual_location = parse_actual_location(brewery_json)
    festival_location = parse_festival_location(brewery_json)

    breweries.push(
      Brewery.new(
        brewery_name,
        website,
        beers,
        actual_location,
        festival_location
      )
    )
  end

  breweries
end

def parse_beer_type(brewery_json, name_prefix, style_prefix, abv_prefix)
  beers = []

  beer_name_prefix = name_prefix ? "#{name_prefix}_beer" : 'beer'
  beer_style_prefix = style_prefix ? "#{style_prefix}_beer" : 'beer'
  beer_abv_prefix = abv_prefix ? "#{abv_prefix}_beer" : 'beer'

  (1..15).map do |index|
    beer_name = brewery_json["#{beer_name_prefix}_#{index}_name"]

    break if beer_name.nil?
    
    if style_prefix == 'thurs_fri' && index == 1
      beer_style = brewery_json["thurs_fri_guild_beer_#{index}_style"]
    else
      beer_style = brewery_json["#{beer_style_prefix}_#{index}_style"]
    end

    beer_style = beer_style.gsub("\u00A0", '')
    beer_abv = brewery_json["#{beer_abv_prefix}_#{index}_abv"].to_f

    beers.push(
      Beer.new(
        beer_name,
        beer_style,
        beer_abv
      )
    )
  end

  beers
end

def parse_beers(brewery_json)
  beers = []

  # Parse regular beers
  regular_beers = parse_beer_type(brewery_json, nil, nil, nil)
  # Parse featured beers
  featured_beers = parse_beer_type( brewery_json, 'fb', 'fb', 'fb')
  # Parse wish we were here beers
  wish_we_were_here_beers = parse_beer_type(brewery_json, 'wwwh', 'wwwh', 'wwwh')
  # Parse heavy medal beers
  heavy_medal_beers = parse_beer_type(brewery_json, 'heavy_medal', 'hm', 'hm')
  # Gluten free beers
  gluten_free_beers = parse_beer_type(brewery_json, 'gf', 'gf', 'gf')
  # Parse non-alcoholic beers
  non_alcoholic_beers = parse_beer_type(brewery_json, 'na', 'na', 'na')
  # Parse Thursday & Friday beers for guilds
  guild_thursday_friday_beers = parse_beer_type(brewery_json, 'thurs_fri', 'thurs_fri', 'thurs_fri')
  # Parse Saturday beers for guilds
  guild_saturday_beers = parse_beer_type(brewery_json, 'saturday', 'saturday', 'saturday')

  beers = regular_beers + featured_beers + wish_we_were_here_beers + heavy_medal_beers + gluten_free_beers + non_alcoholic_beers + guild_thursday_friday_beers + guild_saturday_beers

  beers
end

def parse_festival_location(brewery_json)
  additional_taprooms = []

  additional_taprooms_json = brewery_json['addl_taprooms_fest_brewery']
  if additional_taprooms_json
    additional_taprooms_json.split(',').each do |taproom|
      additional_taprooms.push(taproom.tr('\\"', ''))
    end
  end

  additional_taprooms_json = brewery_json['addl_taprooms_donate_beer']
  if additional_taprooms_json
    additional_taprooms_json.split(',').each do |taproom|
      additional_taprooms.push(taproom.tr('\\"', ''))
    end
  end

  FestivalLocation.new(
    brewery_json['island'],
    brewery_json['booth'],
    additional_taprooms.uniq
  )
end

def parse_actual_location(brewery_json)
  ActualLocation.new(
    brewery_json['city'],
    brewery_json['state'],
    brewery_json['country'],
    brewery_json['brewery_region']
  )
end

def output_json(breweries)
  breweries_jsonized = breweries.map do |brewery|
    {
      name: brewery.name,
      website: brewery.website,
      actual_location: {
        city: brewery.actual_location.city,
        state: brewery.actual_location.state,
        country: brewery.actual_location.country,
        region: brewery.actual_location.region,
      },
      festival_location: {
        island: brewery.festival_location.island,
        booth: brewery.festival_location.booth,
        additional_taprooms: brewery.festival_location.additional_taprooms,
      },
      beers: brewery.beers.map do |beer|
        {
          name: beer.name,
          style: beer.style,
          abv: beer.abv,
        }
      end,
    }
  end

  FileUtils.rm_f('./breweries_2023.json')
  File.write('./breweries_2023.json', breweries_jsonized.to_json)
end

require 'fileutils'
require 'json'

file_name = './official_website_breweries_2023.json'

breweries_json = JSON.parse(File.read(file_name))
breweries = parse_breweries(breweries_json)

beers = breweries.flat_map(&:beers)
puts "#{breweries.size} breweries with #{beers.size} beers"

sours = beers.select { |beer| beer.style == 'Sour Ales, Brett Beers & Lambics' }
puts "#{sours.size} sours"

output_json(breweries)
