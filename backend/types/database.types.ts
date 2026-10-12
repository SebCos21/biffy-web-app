export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type UserRole = "student" | "courier" | "merchant" | "admin";
export type OrderStatus = "programado" | "confirmado" | "preparando" | "en_camino" | "entregado" | "cancelado";
export type TicketStatus = "nuevo" | "preparando" | "listo" | "en_camino" | "entregado" | "rechazado";
export type PaymentType = "card" | "nequi" | "daviplata" | "pse" | "cash";
export type CardBrand = "visa" | "mastercard" | "amex" | "other";

export interface Database {
  public: {
    Tables: {
      universities: {
        Row: {
          id: string;
          name: string;
          domain: string;
          center_lat: number;
          center_lng: number;
          is_active: boolean;
          created_at: string;
        };
      };
      delivery_points: {
        Row: {
          id: string;
          university_id: string | null;
          name: string;
          detail: string;
          lat: number;
          lng: number;
          is_active: boolean;
          created_at: string;
        };
      };
      user_profiles: {
        Row: {
          id: string;
          email: string;
          phone: string | null;
          full_name: string;
          avatar_url: string | null;
          career: string | null;
          university_id: string | null;
          is_student_verified: boolean;
          current_role: UserRole;
          gotas_balance: number;
          created_at: string;
          updated_at: string;
        };
      };
      merchant_profiles: {
        Row: {
          id: string;
          owner_id: string;
          brand_name: string;
          legal_name: string;
          nit: string;
          person_type: string;
          cuisine_category: string;
          description: string | null;
          logo_url: string | null;
          inc_responsible: boolean;
          shows_nutrition: boolean;
          status: string;
          created_at: string;
          updated_at: string;
        };
      };
      sedes: {
        Row: {
          id: string;
          merchant_id: string;
          name: string;
          address: string;
          city: string;
          phone: string;
          lat: number;
          lng: number;
          radius_km: number;
          campus_id: string | null;
          student_discount: number;
          open_hour: number;
          close_hour: number;
          closed_days: number[];
          is_paused: boolean;
          created_at: string;
          updated_at: string;
        };
      };
      dishes: {
        Row: {
          id: string;
          merchant_id: string;
          category_id: string;
          name: string;
          description: string | null;
          section: string;
          price: number;
          emoji: string | null;
          prep_min: number;
          calories: number;
          nutrition_info: Json | null;
          tags: string[];
          allergens: string[];
          photo_url: string | null;
          is_popular: boolean;
          is_available: boolean;
          created_at: string;
          updated_at: string;
        };
      };
      payment_methods: {
        Row: {
          id: string;
          user_id: string;
          type: PaymentType;
          card_brand: CardBrand | null;
          last4: string | null;
          cardholder_name: string | null;
          exp_month: string | null;
          exp_year: string | null;
          gateway_token: string | null;
          is_default: boolean;
          created_at: string;
        };
      };
      orders: {
        Row: {
          id: string;
          user_id: string;
          delivery_point_id: string;
          subtotal: number;
          student_discount: number;
          delivery_fee: number;
          points_discount: number;
          points_used: number;
          total: number;
          status: OrderStatus;
          payment_method_id: string;
          payment_status: string;
          client_security_code: string;
          scheduled_for: string | null;
          created_at: string;
          delivered_at: string | null;
        };
      };
    };
  };
}
