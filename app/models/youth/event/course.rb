# encoding: utf-8

#  Copyright (c) 2012-2015, Pfadibewegung Schweiz. This file is part of
#  hitobito_youth and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_youth.

module Youth::Event::Course
  extend ActiveSupport::Concern

  included do
    class_attribute :tentative_states
    self.tentative_states = [:all]

    self.used_attributes += [:training_days, :tentative_applications]

    # states are used for workflow
    # translations in config/locales
    self.possible_states = %w(created confirmed application_open application_closed
                              assignment_closed canceled completed closed)

    self.tentative_states = %w(created confirmed)

    # Define methods to query if a course is in the given state.
    # eg course.canceled?
    possible_states.each do |state|
      define_method "#{state}?" do
        self.state == state
      end
    end

    ### VALIDATIONS

    validates :state, inclusion: possible_states

    ### CALLBACKS

    before_save :update_attended_participants_state, if: -> { state_changed?(to: 'completed') }

    alias_method_chain :applicants_scope, :tentative
  end

  # may participants apply now?
  def application_possible?
    application_open? &&
    (!application_opening_at || application_opening_at <= ::Date.today)
  end

  def qualification_possible?
    !completed? && !closed?
  end

  def state
    super || possible_states.first
  end

  def tentative_application_possible?
    tentative_applications? && (tentative_states.include?(state) || tentative_states == [:all])
  end

  def tentatives_count
    participations.tentative.count
  end

  def organizers
    Person.
      includes(:roles).
      where(roles: { type: organizing_role_types,
                     group_id: groups.collect(&:id) })
  end

  private

  def update_attended_participants_state
    participants_scope.where(state: 'assigned').update_all(state: 'attended')
  end

  def applicants_scope_with_tentative
    applicants_scope_without_tentative.countable_applicants
  end

  def organizing_role_types
    ::Role.types_with_permission(:layer_full) +
    ::Role.types_with_permission(:layer_and_below_full)
  end

  module ClassMethods
    def application_possible
      where(state: 'application_open').
      where('events.application_opening_at IS NULL OR events.application_opening_at <= ?', ::Date.today)
    end
  end
end