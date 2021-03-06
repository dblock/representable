require 'test_helper'

class InheritTest < MiniTest::Spec
  module SongRepresenter # it's important to have a global module so we can test if stuff gets overridden in the original module.
    include Representable::Hash
    property :name, :as => :title do
      property :string, :as => :str
    end

    property :track, :as => :no
  end

  let (:song) { Song.new(Struct.new(:string).new("Roxanne"), 1) }

  describe ":inherit plain property" do
    representer! do
      include SongRepresenter

      property :track, :inherit => true, :getter => lambda { |*| "n/a" }
    end

    it { SongRepresenter.prepare(song).to_hash.must_equal({"title"=>{"str"=>"Roxanne"}, "no"=>1}) }
    it { representer.prepare(song).to_hash.must_equal({"title"=>{"str"=>"Roxanne"}, "no"=>"n/a"}) } # as: inherited.
  end

  describe ":inherit with empty inline representer" do
    representer! do
      include SongRepresenter

      property :name, :inherit => true do # inherit as: title
        # that doesn't make sense.
      end
    end

    it { SongRepresenter.prepare(Song.new(Struct.new(:string).new("Believe It"), 1)).to_hash.must_equal({"title"=>{"str"=>"Believe It"}, "no"=>1}) }
    it { representer.prepare( Song.new(Struct.new(:string).new("Believe It"), 1)).to_hash.must_equal({"title"=>{"str"=>"Believe It"}, "no"=>1}) }
  end

  describe ":inherit with overriding inline representer" do
    representer! do
      include SongRepresenter

      property :name, :inherit => true do # inherit as: title
        property :string, :as => :s
        property :length
      end
    end

    it { representer.prepare( Song.new(Struct.new(:string, :length).new("Believe It", 10), 1)).to_hash.must_equal({"title"=>{"s"=>"Believe It","length"=>10}, "no"=>1}) }
  end

  describe ":inherit with empty inline and options" do
    representer! do
      include SongRepresenter

      property :name, :inherit => true, :as => :name do # inherit module, only.
        # that doesn't make sense.
      end
    end

    it { SongRepresenter.prepare(Song.new(Struct.new(:string).new("Believe It"), 1)).to_hash.must_equal({"title"=>{"str"=>"Believe It"}, "no"=>1}) }
    it { representer.prepare( Song.new(Struct.new(:string).new("Believe It"), 1)).to_hash.must_equal({"name"=>{"str"=>"Believe It"}, "no"=>1}) }
  end

  describe ":inherit with inline without block but options" do
    representer! do
      include SongRepresenter

      property :name, :inherit => true, :as => :name # FIXME: add :getter or something else dynamic since this is double-wrapped.
    end

    it { SongRepresenter.prepare(Song.new(Struct.new(:string).new("Believe It"), 1)).to_hash.must_equal({"title"=>{"str"=>"Believe It"}, "no"=>1}) }
    it { representer.prepare( Song.new(Struct.new(:string).new("Believe It"), 1)).to_hash.must_equal({"name"=>{"str"=>"Believe It"}, "no"=>1}) }
  end



  # no :inherit
  describe "overwriting without :inherit" do
    representer! do
      include SongRepresenter

      property :track, :representable => true
    end

    it "replaces inherited property" do
      representer.representable_attrs.size.must_equal 2

      definition = representer.representable_attrs[:track] # TODO: find a better way to assert Definition identity.
      definition.keys.size.must_equal 2
      definition[:representable].   must_equal true
      definition[:as].evaluate(nil).must_equal "track" # was "no".
    end
  end

end