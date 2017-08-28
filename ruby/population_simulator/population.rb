#!/usr/bin/env ruby
require 'yaml'

class Person
  def self.person_template
    @person = {
      sex: 'nil',
      age: 1,
      native: 1,
      eye: 'nil',
      hair: 'nil',
    }
  end

  def self.new(population)
    @pop = population
    person = person_template
    person[:sex] = sex_genes
    person[:eye] = eye_genes
    person[:hair] = hair_genes

    person
  end

  def self.sex_genes
    %w[male female][rand(2)]
  end

  def self.hair_genes
    parents = []

    @pop.each_value do |parent|
      parent.each_value do |attr|
        parents.push(attr[:hair])
      end
    end

    parents[rand(parents.length)]
  end

  def self.eye_genes
    parents = []

    @pop.each_value do |parent|
      parent.each_value do |attr|
        parents.push(attr[:eye])
      end
    end

    parents[rand(parents.length)]
  end
end

class Population
  def initialize(population)
    @eyecolors = %w[brown green hazel blue]
    @haircolors = %w[brown black blonde red]
    @pop = population
  end

  def reproduce
    if @pop[:male].count >= 1 && @pop[:female].count >= 1
      person = Person.new(@pop)
      sex = person[:sex].to_sym
      id = @pop[sex].keys.max + 1

      @pop[sex][id] = person
      @pop
    else
      puts "This population is unable to reproduce!"
      return false
    end
  end

  def age
    @pop.each_value do |person|
      person.each_value do |p|
        p[:age] += 1
      end
    end
  end

  def immigration

  end

  def report
    males = @pop[:male].count
    females = @pop[:female].count

    puts "Population:
Males: #{males}
Females: #{females}
"
  end

  def save
    File.write('./population.yml', @pop.to_yaml)
  end
end


if __FILE__ == $PROGRAM_NAME
  pop_file = './population.yml'
  population = 'nil'

  if File.exist?(pop_file)
    print "Continue from existing population? (Y/N): "
    input = gets.chomp

    if input =~ /^y(es)?$/i
      population = YAML.load_file('./population.yml')
    else
      population = YAML.load_file('./pop_fresh.yml')
    end
  else
    population = YAML.load_file('./pop_fresh.yml')
  end
  
  pop = Population.new population

  100.times do
    pop.reproduce
    pop.age
  end

  pop.report
  pop.save
end
