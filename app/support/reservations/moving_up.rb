# Support for finding the next available time and moving a reservation
# up to that next time slot
module Reservations::MovingUp
  #
  # Returns a new reservation with the reserve_*_at times updated
  # to the next accommodating time slot on the calendar from NOW. Returns nil
  # if there is no such time slot. For read-only purposes.
  def earliest_possible
    after = 1.minute.from_now

    next_res = product.next_available_reservation(after, duration_mins.minutes, :exclude => self, :user => user)
    return nil if next_res.nil? || next_res.reserve_start_at > reserve_start_at
    next_res
  end

  def move_to_earliest
    earliest_found = earliest_possible
    if earliest_found
      self.reserve_start_at = earliest_found.reserve_start_at
      self.reserve_end_at = earliest_found.reserve_end_at
      if save
        return true
      else
        self.errors.add(:base, :move_failed)
      end
    else
      self.errors.add(:base, :cannot_move)
    end
    false
  end

  #
  # returns true if this reservation can be moved to
  # an earlier time slot, false otherwise
  def can_move?
    !(cancelled? || order_detail.complete? || earliest_possible.nil?)
  end
end
