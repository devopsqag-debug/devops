export interface Service {
  id: string;
  name: string;
  description: string | null;
  duration_minutes: number;
  price_cents: number;
  is_active: boolean;
  created_at: string;
}

export interface Booking {
  id: string;
  user_id: string;
  service_id: string;
  start_time: string;
  end_time: string;
  status: 'confirmed' | 'cancelled' | 'completed';
  notes: string | null;
  created_at: string;
  updated_at: string;
  services?: Service;
}

export interface BookingWithService extends Booking {
  services: Service;
}

export interface TimeSlot {
  start: Date;
  end: Date;
  available: boolean;
}
