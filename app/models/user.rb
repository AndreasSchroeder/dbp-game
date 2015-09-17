class User < ActiveRecord::Base

#  has_many :fights
  has_many :attacks, :class_name => 'Fight', :foreign_key => "attacker_id", inverse_of: :attacker
  has_many :defends, :class_name => 'Fight', :foreign_key  => "defender_id", inverse_of: :defender

  has_one :rank, dependent: :destroy
  has_many :science_instances, dependent: :destroy
  has_many :sciences, :through => :science_instances
  has_many :unit_instances, dependent: :destroy
  has_many :units, :through => :unit_instances
  has_many :user_ships, dependent: :destroy
  has_many :ships, :through => :user_ships
  has_many :notifications, dependent: :destroy
  has_many :messages, through: :notifications
  has_many :expedition_instances, dependent: :destroy
  has_many :expeditions, :through => :expedition_instances
  after_initialize :init, :if => :new_record?
  belongs_to :active_ship, foreign_key: :activeShip, class: Ship

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :authentication_keys => [:login]

  attr_accessor :login

  validates :username,
  :presence => true,
  :length => {
    :minimum => 3,
    :maximum => 12,
    :message => "Username must be between 3 and 12 characters"
  },
  :uniqueness => {
    :case_sensitive => false
  }

  #f:<condition_id>:<level>,*
  def check_condition(conditions)
    condition_split = conditions.split(",")

    condition_split.each do |condition|
      condition_elements = condition.split(":")
      if(condition_elements[0].eql? "f")
        science_instance = ScienceInstance.find_by(:user_id => self.id, :science_id => Science.find_by(:science_condition_id => condition_elements[1]).id)
        if not (science_instance.level >= condition_elements[2].to_i)
          return false
        end
      end
    end
    return true
  end

  def distance_to(user)
    offset = 20
    factor = 10
    end_score = user.rank.score
    start_score = self.rank.score

    distance = factor * (offset + (start_score - end_score))

    if(distance < 0)
      return -1 * distance
    else
      return distance
    end
  end

  def is_being_attacked
    FightingFleet.all.each do |fleet|
      if(fleet.mission && fleet.get_target_ship.user.id == self.id && fleet.mission.to_i == 1)
        return true
      end
    end
    return false
  end

  def active_ship
    return Ship.find_by(id: self.activeShip)
  end
  
  def cheat
    current_user.remove_resources(-10000, -10000, -10000)
  end

  def get_science_instance(science)
    return science_instances.find_by(:science_id => science.id)
  end

  def is_elsewhere_researching(instance)
    ship = Ship.find_by(:id => instance.research_ship || self.activeShip)
    return ship.build_lists.find_by(typeSign: 'r', instance_id: instance.id) != nil && instance.start_time != nil
  end

  def is_researching(instance)
    ship = Ship.find_by(:id => instance.research_ship || self.activeShip)
    return (!enough_network(instance, ship) || self.active_ship.build_lists.find_by(typeSign: 'n', instance_id: instance.id) != nil) && ship.build_lists.find_by(typeSign: 'r', instance_id: instance.id) != nil && instance.start_time != nil
  end

  def enough_network(instance, ship)
    if ship == self.active_ship
      return false
    else
      dummylists = BuildList.where(typeSign: 'n', instance_id: instance.id)
      dummycount = 0
      if (dummylists!= nil)
        dummycount = dummylists.count
      end
      if(dummycount >= instance.user.science_instances.find_by(:science_id => 4008).level)
        return false
      else
        return true
      end
    end
  end

  def can_research(instance)
    level = instance.level
    condition = instance.check_conditions()

    metal = instance.science.get_metal_cost(level)
    crystal = instance.science.get_crystal_cost(level)
    fuel = instance.science.get_fuel_cost(level)

    enough_resources = self.has_enough_resources(metal, crystal, fuel)
    if self.is_elsewhere_researching(instance) && !self.is_researching(instance)
      enough_resources = true
    end

    return condition && !self.is_researching(instance) && enough_resources && !(instance.level_cap_reached) && research_count_control
  end
  
  def research_count_control
    back = true
    science_instances.each do |instance|
      if(instance.research_ship == self.activeShip)
        back = false
      end
      if(self.active_ship.build_lists.find_by(typeSign: 'n', instance_id: instance.id) != nil)
        back = false
      end
    end
    return back
  end

#  def can_build_unit(unit, ship)
#    condition = self.check_condition(unit.conditions) 
#    not_building = ship.get_unit_instance(unit).start_time.nil?
#
#    metal = unit.get_metal_cost() 
#    crystal = unit.get_crystal_cost() 
#    fuel = unit.get_fuel_cost()
#
#    enough_resources = self.has_enough_resources(metal, crystal, fuel)
#    return condition && not_building && enough_resources 
#  end

  def has_min_science_level(science, level)
    return self.get_science_instance(science).level >= level.to_i
  end

  def ship_counter
    count = 0
    user_ships.each do
      count += 1
    end
    return count
  end
  
  def next_ship_allowed
    if ship_counter < 3
      return true
    end
    if ship_counter > self.get_science_instance(Science.find_by(id: '4009')).level + 3
      return false
    else 
      return true
    end    
  end

  def user_ships
    return UserShip.all.where(:user_id => self.id)
  end

  def has_min_station_level(station, level)
    return ShipsStation.find_by(:ship_id => self.active_ship.id, :station_id => station.id).level >= level.to_i
  end

  def get_metal()
     ship = active_ship

    if(ship.nil?)
      return -1;
    end
    return ship.metal
  end

  def get_crystal()
     ship = active_ship

    if(ship.nil?)
      return -1;
    end
    return ship.cristal
  end

  def get_fuel()
     ship = active_ship

    if(ship.nil?)
      return -1;
    end
    return ship.fuel
  end

  def has_enough_metal(metal)
    ship_metal = self.get_metal
    if(ship_metal < metal)
      return false
    end
    return true
  end

  def has_enough_crystal(crystal)
    ship_crystal = self.get_crystal
    if(ship_crystal < crystal)
      return false
    end
    return true
  end

  def has_enough_fuel(fuel)
    ship_fuel = self.get_fuel
    if(ship_fuel < fuel)
      return false
    end
    return true
  end

  def has_enough_resources(metal, crystal, fuel)
    selfMetal = self.has_enough_metal(metal)
    selfCrystal = self.has_enough_crystal(crystal)
    selfFuel = self.has_enough_fuel(fuel)

    return selfMetal && selfCrystal && selfFuel
  end

  def remove_resources(metal, crystal, fuel, ship)
    ship_metal = ship.metal - metal
    ship_crystal = ship.cristal - crystal
    ship_fuel = ship.fuel - fuel

    ship.metal = (ship_metal < 0 ? 0 : ship_metal)
    ship.cristal = (ship_crystal < 0 ? 0 : ship_crystal)
    ship.fuel = (ship_fuel < 0 ? 0 : ship_fuel)

    ship.save
  end

  def remove_resources_from_current_ship(metal, crystal, fuel)
    self.remove_resources(metal, crystal, fuel, active_ship)
  end

  def add_resources(metal, crystal, fuel, ship)
    ship.metal = ship.metal + metal
    ship.cristal = ship.cristal + crystal
    ship.fuel = ship.fuel + fuel

    ship.save
  end

  def add_resources_to_current_ship(metal, crystal, fuel)
    self.add_resources(metal, crystal, fuel, active_ship)
  end

  def self.find_for_database_authentication(warden_conditions)
      conditions = warden_conditions.dup
      if login = conditions.delete(:login)
        where(conditions.to_h).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
      else
        where(conditions.to_h).first
      end
    end

  def login=(login)
    @login = login
  end

  def login
    @login || self.username || self.email
  end

  def create_ship(ship_name)
    if self.ship_counter < 9
      if self.ship_counter>1 && has_enough_resources(200000,100000,0)
        remove_resources_from_current_ship(200000, 100000, 0)
      end
      s = self.ships.build(ship_name)
      self.user_ships.build(user: self, ship: s)
    end
    return s
  end

  def select_ship(shipID)
    self.activeShip=shipID
    self.save
  end

  def incr_user_rank(points)
    if points.is_a? Numeric
      self.rank.score += points
      self.rank.save
    end
  end

  def is_user
    return right_level >= 0
  end

  def is_premium_user
    return right_level >= 1
  end

  def is_moderator
    return right_level >= 2
  end

  def is_admin
    return right_level >= 3
  end

  def is_superadmin
    return right_level >= 4
  end

  private
    def init
      Science.all.each do |science|
        if not(science_instances.exists?(:science_id => science.id, :user_id => self.id))
          science_instances.build(science: science, level: 0, research_amount: 0)
        end
      end
    end
end
