export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "12.2.3 (519615d)"
  }
  public: {
    Tables: {
      admins: {
        Row: {
          created_at: string
          is_active: boolean
          roles: Database["public"]["Enums"]["admin_role_enum"][]
          served_pincodes: number[] | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          is_active?: boolean
          roles: Database["public"]["Enums"]["admin_role_enum"][]
          served_pincodes?: number[] | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          is_active?: boolean
          roles?: Database["public"]["Enums"]["admin_role_enum"][]
          served_pincodes?: number[] | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      customer_documents: {
        Row: {
          created_at: string
          description: string | null
          document_id: string
          document_type: string
          document_url: string
          file_name: string | null
          updated_at: string
          uploaded_at: string
          uploaded_by: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          document_id?: string
          document_type: string
          document_url: string
          file_name?: string | null
          updated_at?: string
          uploaded_at?: string
          uploaded_by?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          description?: string | null
          document_id?: string
          document_type?: string
          document_url?: string
          file_name?: string | null
          updated_at?: string
          uploaded_at?: string
          uploaded_by?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_documents_uploaded_by_fkey"
            columns: ["uploaded_by"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["user_id"]
          },
        ]
      }
      customers: {
        Row: {
          created_at: string
          expiry_date: string
          profile_details: Json
          updated_at: string
          user_id: string
          visit_balance: number
        }
        Insert: {
          created_at?: string
          expiry_date?: string
          profile_details?: Json
          updated_at?: string
          user_id: string
          visit_balance?: number
        }
        Update: {
          created_at?: string
          expiry_date?: string
          profile_details?: Json
          updated_at?: string
          user_id?: string
          visit_balance?: number
        }
        Relationships: []
      }
      customers_interaction: {
        Row: {
          admin_notes: string | null
          assigned_sales_admin_id: string | null
          assigned_tenant_telecaller_id: string | null
          created_at: string
          interaction_id: string
          property_id: string
          scheduled_for: string | null
          status: Database["public"]["Enums"]["interaction_status_enum"]
          telecaller_assigned_at: string | null
          updated_at: string
          user_id: string
          visited_at: string | null
        }
        Insert: {
          admin_notes?: string | null
          assigned_sales_admin_id?: string | null
          assigned_tenant_telecaller_id?: string | null
          created_at?: string
          interaction_id?: string
          property_id: string
          scheduled_for?: string | null
          status?: Database["public"]["Enums"]["interaction_status_enum"]
          telecaller_assigned_at?: string | null
          updated_at?: string
          user_id: string
          visited_at?: string | null
        }
        Update: {
          admin_notes?: string | null
          assigned_sales_admin_id?: string | null
          assigned_tenant_telecaller_id?: string | null
          created_at?: string
          interaction_id?: string
          property_id?: string
          scheduled_for?: string | null
          status?: Database["public"]["Enums"]["interaction_status_enum"]
          telecaller_assigned_at?: string | null
          updated_at?: string
          user_id?: string
          visited_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "customers_interaction_assigned_sales_admin_id_fkey"
            columns: ["assigned_sales_admin_id"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "customers_interaction_assigned_tenant_telecaller_id_fkey"
            columns: ["assigned_tenant_telecaller_id"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "customers_interaction_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "customers_interaction_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["user_id"]
          },
        ]
      }
      management_service_plans: {
        Row: {
          created_at: string
          description: string | null
          is_active: boolean
          name: string
          percentage: number
          plan_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          is_active?: boolean
          name: string
          percentage: number
          plan_id?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          is_active?: boolean
          name?: string
          percentage?: number
          plan_id?: string
          updated_at?: string
        }
        Relationships: []
      }
      otp_sent_log: {
        Row: {
          id: number
          phone_number: string
          sent_at: string
        }
        Insert: {
          id?: number
          phone_number: string
          sent_at?: string
        }
        Update: {
          id?: number
          phone_number?: string
          sent_at?: string
        }
        Relationships: []
      }
      properties: {
        Row: {
          address: string
          admin_notes: string | null
          admin_status: Database["public"]["Enums"]["property_admin_status_enum"]
          advance_amount: number | null
          area: number
          area_unit: Database["public"]["Enums"]["area_unit_enum"]
          availability_status:
            | Database["public"]["Enums"]["availability_status_enum"]
            | null
          can_reachout: boolean
          city: string
          created_at: string
          description: string | null
          details: Json
          inventory_details: Json
          is_exclusive: boolean
          is_featured: boolean
          is_listed: boolean
          latitude: number | null
          listing_type: Database["public"]["Enums"]["listing_type_enum"]
          locality: string
          longitude: number | null
          management_plan_id: string | null
          nearest_busstop: number | null
          nearest_gym: number | null
          nearest_hospital: number | null
          nearest_park: number | null
          nearest_school: number | null
          nearest_swimmingpool: number | null
          pincode: number | null
          price: number
          property_id: string
          property_type: Database["public"]["Enums"]["property_type_enum"]
          proximity_unit:
            | Database["public"]["Enums"]["proximity_unit_enum"]
            | null
          rent_due_day: number | null
          submitted_at: string
          submitter: string | null
          submitter_notes: string | null
          submitter_type:
            | Database["public"]["Enums"]["submitter_type_enum"]
            | null
          tenant: string | null
          updated_at: string
          year_built: number | null
          youtube_url: string | null
        }
        Insert: {
          address: string
          admin_notes?: string | null
          admin_status?: Database["public"]["Enums"]["property_admin_status_enum"]
          advance_amount?: number | null
          area: number
          area_unit: Database["public"]["Enums"]["area_unit_enum"]
          availability_status?:
            | Database["public"]["Enums"]["availability_status_enum"]
            | null
          can_reachout?: boolean
          city: string
          created_at?: string
          description?: string | null
          details: Json
          inventory_details?: Json
          is_exclusive?: boolean
          is_featured?: boolean
          is_listed?: boolean
          latitude?: number | null
          listing_type: Database["public"]["Enums"]["listing_type_enum"]
          locality: string
          longitude?: number | null
          management_plan_id?: string | null
          nearest_busstop?: number | null
          nearest_gym?: number | null
          nearest_hospital?: number | null
          nearest_park?: number | null
          nearest_school?: number | null
          nearest_swimmingpool?: number | null
          pincode?: number | null
          price: number
          property_id?: string
          property_type: Database["public"]["Enums"]["property_type_enum"]
          proximity_unit?:
            | Database["public"]["Enums"]["proximity_unit_enum"]
            | null
          rent_due_day?: number | null
          submitted_at?: string
          submitter?: string | null
          submitter_notes?: string | null
          submitter_type?:
            | Database["public"]["Enums"]["submitter_type_enum"]
            | null
          tenant?: string | null
          updated_at?: string
          year_built?: number | null
          youtube_url?: string | null
        }
        Update: {
          address?: string
          admin_notes?: string | null
          admin_status?: Database["public"]["Enums"]["property_admin_status_enum"]
          advance_amount?: number | null
          area?: number
          area_unit?: Database["public"]["Enums"]["area_unit_enum"]
          availability_status?:
            | Database["public"]["Enums"]["availability_status_enum"]
            | null
          can_reachout?: boolean
          city?: string
          created_at?: string
          description?: string | null
          details?: Json
          inventory_details?: Json
          is_exclusive?: boolean
          is_featured?: boolean
          is_listed?: boolean
          latitude?: number | null
          listing_type?: Database["public"]["Enums"]["listing_type_enum"]
          locality?: string
          longitude?: number | null
          management_plan_id?: string | null
          nearest_busstop?: number | null
          nearest_gym?: number | null
          nearest_hospital?: number | null
          nearest_park?: number | null
          nearest_school?: number | null
          nearest_swimmingpool?: number | null
          pincode?: number | null
          price?: number
          property_id?: string
          property_type?: Database["public"]["Enums"]["property_type_enum"]
          proximity_unit?:
            | Database["public"]["Enums"]["proximity_unit_enum"]
            | null
          rent_due_day?: number | null
          submitted_at?: string
          submitter?: string | null
          submitter_notes?: string | null
          submitter_type?:
            | Database["public"]["Enums"]["submitter_type_enum"]
            | null
          tenant?: string | null
          updated_at?: string
          year_built?: number | null
          youtube_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "properties_management_plan_id_fkey"
            columns: ["management_plan_id"]
            isOneToOne: false
            referencedRelation: "management_service_plans"
            referencedColumns: ["plan_id"]
          },
        ]
      }
      property_documents: {
        Row: {
          created_at: string
          description: string | null
          document_id: string
          document_type: string
          document_url: string
          file_name: string | null
          property_id: string
          updated_at: string
          uploaded_at: string
          uploaded_by: string | null
        }
        Insert: {
          created_at?: string
          description?: string | null
          document_id?: string
          document_type: string
          document_url: string
          file_name?: string | null
          property_id: string
          updated_at?: string
          uploaded_at?: string
          uploaded_by?: string | null
        }
        Update: {
          created_at?: string
          description?: string | null
          document_id?: string
          document_type?: string
          document_url?: string
          file_name?: string | null
          property_id?: string
          updated_at?: string
          uploaded_at?: string
          uploaded_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "property_documents_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "property_documents_uploaded_by_fkey"
            columns: ["uploaded_by"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["user_id"]
          },
        ]
      }
      property_images: {
        Row: {
          created_at: string
          description: string | null
          display_order: number
          image_id: string
          image_url: string
          is_internal_image: boolean
          property_id: string
          updated_at: string
          uploaded_by: string | null
        }
        Insert: {
          created_at?: string
          description?: string | null
          display_order?: number
          image_id?: string
          image_url: string
          is_internal_image?: boolean
          property_id: string
          updated_at?: string
          uploaded_by?: string | null
        }
        Update: {
          created_at?: string
          description?: string | null
          display_order?: number
          image_id?: string
          image_url?: string
          is_internal_image?: boolean
          property_id?: string
          updated_at?: string
          uploaded_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "property_images_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["property_id"]
          },
        ]
      }
      property_marketing_assignments: {
        Row: {
          assigned_admin_id: string
          assigned_at: string
          property_id: string
        }
        Insert: {
          assigned_admin_id: string
          assigned_at?: string
          property_id: string
        }
        Update: {
          assigned_admin_id?: string
          assigned_at?: string
          property_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "property_marketing_assignments_assigned_admin_id_fkey"
            columns: ["assigned_admin_id"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "property_marketing_assignments_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: true
            referencedRelation: "properties"
            referencedColumns: ["property_id"]
          },
        ]
      }
      property_owner_contact_assignments: {
        Row: {
          assigned_admin_id: string
          assigned_at: string
          property_id: string
        }
        Insert: {
          assigned_admin_id: string
          assigned_at?: string
          property_id: string
        }
        Update: {
          assigned_admin_id?: string
          assigned_at?: string
          property_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "property_owner_contact_assignments_assigned_admin_id_fkey"
            columns: ["assigned_admin_id"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "property_owner_contact_assignments_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: true
            referencedRelation: "properties"
            referencedColumns: ["property_id"]
          },
        ]
      }
      property_visit_assignment_interactions: {
        Row: {
          interaction_id: string
          visit_assignment_id: string
        }
        Insert: {
          interaction_id: string
          visit_assignment_id: string
        }
        Update: {
          interaction_id?: string
          visit_assignment_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "property_visit_assignment_interactions_interaction_id_fkey"
            columns: ["interaction_id"]
            isOneToOne: false
            referencedRelation: "customers_interaction"
            referencedColumns: ["interaction_id"]
          },
          {
            foreignKeyName: "property_visit_assignment_interactions_visit_assignment_id_fkey"
            columns: ["visit_assignment_id"]
            isOneToOne: false
            referencedRelation: "property_visit_assignments"
            referencedColumns: ["visit_assignment_id"]
          },
        ]
      }
      property_visit_assignments: {
        Row: {
          assigned_sales_admin_id: string | null
          created_at: string
          updated_at: string
          user_id: string
          visit_assignment_id: string
          visit_date: string
        }
        Insert: {
          assigned_sales_admin_id?: string | null
          created_at?: string
          updated_at?: string
          user_id: string
          visit_assignment_id?: string
          visit_date: string
        }
        Update: {
          assigned_sales_admin_id?: string | null
          created_at?: string
          updated_at?: string
          user_id?: string
          visit_assignment_id?: string
          visit_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "property_visit_assignments_assigned_sales_admin_id_fkey"
            columns: ["assigned_sales_admin_id"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["user_id"]
          },
        ]
      }
      rent_payments: {
        Row: {
          amount: number
          created_at: string
          notes: string | null
          paid_by_user_id: string
          payment_date: string
          payment_id: string
          payment_method: string | null
          rent_record_id: string
          transaction_ref: string | null
        }
        Insert: {
          amount: number
          created_at?: string
          notes?: string | null
          paid_by_user_id: string
          payment_date?: string
          payment_id?: string
          payment_method?: string | null
          rent_record_id: string
          transaction_ref?: string | null
        }
        Update: {
          amount?: number
          created_at?: string
          notes?: string | null
          paid_by_user_id?: string
          payment_date?: string
          payment_id?: string
          payment_method?: string | null
          rent_record_id?: string
          transaction_ref?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "rent_payments_rent_record_id_fkey"
            columns: ["rent_record_id"]
            isOneToOne: false
            referencedRelation: "rent_records"
            referencedColumns: ["rent_record_id"]
          },
        ]
      }
      rent_records: {
        Row: {
          amount_due: number
          amount_paid: number
          created_at: string
          due_date: string
          landlord_user_id: string
          notes: string | null
          period_end_date: string
          period_start_date: string
          property_id: string
          rent_record_id: string
          status: Database["public"]["Enums"]["rent_status_enum"]
          tenant_user_id: string
          updated_at: string
        }
        Insert: {
          amount_due: number
          amount_paid?: number
          created_at?: string
          due_date: string
          landlord_user_id: string
          notes?: string | null
          period_end_date: string
          period_start_date: string
          property_id: string
          rent_record_id?: string
          status?: Database["public"]["Enums"]["rent_status_enum"]
          tenant_user_id: string
          updated_at?: string
        }
        Update: {
          amount_due?: number
          amount_paid?: number
          created_at?: string
          due_date?: string
          landlord_user_id?: string
          notes?: string | null
          period_end_date?: string
          period_start_date?: string
          property_id?: string
          rent_record_id?: string
          status?: Database["public"]["Enums"]["rent_status_enum"]
          tenant_user_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "rent_records_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["property_id"]
          },
        ]
      }
      rental_applications: {
        Row: {
          admin_notes: string | null
          application_data: Json
          application_id: string
          assigned_admin_id: string | null
          interaction_id: string
          landlord_user_id: string
          property_id: string
          status: Database["public"]["Enums"]["rental_application_status_enum"]
          status_updated_at: string
          submitted_at: string
          updated_at: string
          user_id: string
        }
        Insert: {
          admin_notes?: string | null
          application_data: Json
          application_id?: string
          assigned_admin_id?: string | null
          interaction_id: string
          landlord_user_id: string
          property_id: string
          status?: Database["public"]["Enums"]["rental_application_status_enum"]
          status_updated_at?: string
          submitted_at?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          admin_notes?: string | null
          application_data?: Json
          application_id?: string
          assigned_admin_id?: string | null
          interaction_id?: string
          landlord_user_id?: string
          property_id?: string
          status?: Database["public"]["Enums"]["rental_application_status_enum"]
          status_updated_at?: string
          submitted_at?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "rental_applications_assigned_admin_id_fkey"
            columns: ["assigned_admin_id"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "rental_applications_interaction_id_fkey"
            columns: ["interaction_id"]
            isOneToOne: false
            referencedRelation: "customers_interaction"
            referencedColumns: ["interaction_id"]
          },
          {
            foreignKeyName: "rental_applications_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["property_id"]
          },
        ]
      }
      round_robin_state: {
        Row: {
          assignment_group: string
          last_assigned_admin_id: string | null
          last_assigned_at: string | null
          updated_at: string
        }
        Insert: {
          assignment_group: string
          last_assigned_admin_id?: string | null
          last_assigned_at?: string | null
          updated_at?: string
        }
        Update: {
          assignment_group?: string
          last_assigned_admin_id?: string | null
          last_assigned_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "round_robin_state_last_assigned_admin_id_fkey"
            columns: ["last_assigned_admin_id"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["user_id"]
          },
        ]
      }
      service_sms_log: {
        Row: {
          created_at: string
          id: number
          sms_type: Database["public"]["Enums"]["sms_type_enum"]
          status: Database["public"]["Enums"]["sms_status_enum"]
          to_phone_number: string
          updated_at: string
          variables: string[] | null
        }
        Insert: {
          created_at?: string
          id?: number
          sms_type: Database["public"]["Enums"]["sms_type_enum"]
          status?: Database["public"]["Enums"]["sms_status_enum"]
          to_phone_number: string
          updated_at?: string
          variables?: string[] | null
        }
        Update: {
          created_at?: string
          id?: number
          sms_type?: Database["public"]["Enums"]["sms_type_enum"]
          status?: Database["public"]["Enums"]["sms_status_enum"]
          to_phone_number?: string
          updated_at?: string
          variables?: string[] | null
        }
        Relationships: []
      }
      services: {
        Row: {
          category: Database["public"]["Enums"]["service_category_enum"] | null
          created_at: string
          description: string | null
          service_id: number
          service_name: string
        }
        Insert: {
          category?: Database["public"]["Enums"]["service_category_enum"] | null
          created_at?: string
          description?: string | null
          service_id?: number
          service_name: string
        }
        Update: {
          category?: Database["public"]["Enums"]["service_category_enum"] | null
          created_at?: string
          description?: string | null
          service_id?: number
          service_name?: string
        }
        Relationships: []
      }
      ticket_comments: {
        Row: {
          comment_id: number
          comment_text: string
          created_at: string
          is_internal: boolean
          ticket_id: number
          user_id: string
        }
        Insert: {
          comment_id?: number
          comment_text: string
          created_at?: string
          is_internal?: boolean
          ticket_id: number
          user_id: string
        }
        Update: {
          comment_id?: number
          comment_text?: string
          created_at?: string
          is_internal?: boolean
          ticket_id?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ticket_comments_ticket_id_fkey"
            columns: ["ticket_id"]
            isOneToOne: false
            referencedRelation: "tickets"
            referencedColumns: ["ticket_id"]
          },
        ]
      }
      ticket_images: {
        Row: {
          created_at: string
          description: string | null
          image_id: string
          image_url: string
          ticket_id: number
          uploaded_by: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          image_id?: string
          image_url: string
          ticket_id: number
          uploaded_by: string
        }
        Update: {
          created_at?: string
          description?: string | null
          image_id?: string
          image_url?: string
          ticket_id?: number
          uploaded_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "ticket_images_ticket_id_fkey"
            columns: ["ticket_id"]
            isOneToOne: false
            referencedRelation: "tickets"
            referencedColumns: ["ticket_id"]
          },
        ]
      }
      tickets: {
        Row: {
          assigned_support_admin_id: string | null
          assigned_to_vendor_id: string | null
          category: Database["public"]["Enums"]["ticket_category_enum"]
          closed_at: string | null
          created_at: string
          description: string
          priority: Database["public"]["Enums"]["ticket_priority_enum"]
          property_id: string
          raised_by_user_id: string
          resolution_notes: string | null
          resolved_at: string | null
          status: Database["public"]["Enums"]["ticket_status_enum"]
          subject: string
          ticket_id: number
          updated_at: string
        }
        Insert: {
          assigned_support_admin_id?: string | null
          assigned_to_vendor_id?: string | null
          category: Database["public"]["Enums"]["ticket_category_enum"]
          closed_at?: string | null
          created_at?: string
          description: string
          priority?: Database["public"]["Enums"]["ticket_priority_enum"]
          property_id: string
          raised_by_user_id: string
          resolution_notes?: string | null
          resolved_at?: string | null
          status?: Database["public"]["Enums"]["ticket_status_enum"]
          subject: string
          ticket_id?: number
          updated_at?: string
        }
        Update: {
          assigned_support_admin_id?: string | null
          assigned_to_vendor_id?: string | null
          category?: Database["public"]["Enums"]["ticket_category_enum"]
          closed_at?: string | null
          created_at?: string
          description?: string
          priority?: Database["public"]["Enums"]["ticket_priority_enum"]
          property_id?: string
          raised_by_user_id?: string
          resolution_notes?: string | null
          resolved_at?: string | null
          status?: Database["public"]["Enums"]["ticket_status_enum"]
          subject?: string
          ticket_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tickets_assigned_support_admin_id_fkey"
            columns: ["assigned_support_admin_id"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "tickets_assigned_to_vendor_id_fkey"
            columns: ["assigned_to_vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["vendor_id"]
          },
          {
            foreignKeyName: "tickets_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["property_id"]
          },
        ]
      }
      transactions: {
        Row: {
          admin_notes: string | null
          amount: number
          created_at: string
          error_message: string | null
          plan_id: string
          razorpay_order_id: string | null
          razorpay_payment_id: string | null
          razorpay_signature: string | null
          status: string
          transaction_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          admin_notes?: string | null
          amount: number
          created_at?: string
          error_message?: string | null
          plan_id: string
          razorpay_order_id?: string | null
          razorpay_payment_id?: string | null
          razorpay_signature?: string | null
          status: string
          transaction_id?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          admin_notes?: string | null
          amount?: number
          created_at?: string
          error_message?: string | null
          plan_id?: string
          razorpay_order_id?: string | null
          razorpay_payment_id?: string | null
          razorpay_signature?: string | null
          status?: string
          transaction_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "transactions_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "visit_plans"
            referencedColumns: ["plan_id"]
          },
          {
            foreignKeyName: "transactions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["user_id"]
          },
        ]
      }
      vendor_services: {
        Row: {
          created_at: string
          service_id: number
          vendor_id: string
        }
        Insert: {
          created_at?: string
          service_id: number
          vendor_id: string
        }
        Update: {
          created_at?: string
          service_id?: number
          vendor_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "vendor_services_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "services"
            referencedColumns: ["service_id"]
          },
          {
            foreignKeyName: "vendor_services_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["vendor_id"]
          },
        ]
      }
      vendors: {
        Row: {
          address: string | null
          company_name: string
          contact_name: string | null
          created_at: string
          email: string | null
          notes: string | null
          phone: string | null
          status: Database["public"]["Enums"]["vendor_status_enum"]
          updated_at: string
          vendor_id: string
        }
        Insert: {
          address?: string | null
          company_name: string
          contact_name?: string | null
          created_at?: string
          email?: string | null
          notes?: string | null
          phone?: string | null
          status?: Database["public"]["Enums"]["vendor_status_enum"]
          updated_at?: string
          vendor_id?: string
        }
        Update: {
          address?: string | null
          company_name?: string
          contact_name?: string | null
          created_at?: string
          email?: string | null
          notes?: string | null
          phone?: string | null
          status?: Database["public"]["Enums"]["vendor_status_enum"]
          updated_at?: string
          vendor_id?: string
        }
        Relationships: []
      }
      visit_plans: {
        Row: {
          created_at: string
          description: string | null
          is_active: boolean
          name: string
          plan_id: string
          price: number
          updated_at: string
          visits: number
        }
        Insert: {
          created_at?: string
          description?: string | null
          is_active?: boolean
          name: string
          plan_id?: string
          price: number
          updated_at?: string
          visits: number
        }
        Update: {
          created_at?: string
          description?: string | null
          is_active?: boolean
          name?: string
          plan_id?: string
          price?: number
          updated_at?: string
          visits?: number
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      activate_admin: {
        Args: { p_user_id: string }
        Returns: undefined
      }
      add_admin_role: {
        Args: {
          p_role_to_add: Database["public"]["Enums"]["admin_role_enum"]
          p_user_id: string
        }
        Returns: undefined
      }
      add_ticket_comment_admin: {
        Args: {
          p_comment_text: string
          p_is_internal?: boolean
          p_ticket_id: number
        }
        Returns: undefined
      }
      add_ticket_comment_customer: {
        Args: { p_comment_text: string; p_ticket_id_input: number }
        Returns: undefined
      }
      add_to_wishlist_customer: {
        Args: { p_property_id: string }
        Returns: string
      }
      admin_add_rental_application_note: {
        Args: { p_application_id: string; p_note: string }
        Returns: undefined
      }
      admin_assign_rental_application: {
        Args: { p_application_id: string; p_target_admin_id: string }
        Returns: undefined
      }
      admin_finalize_lease_from_application: {
        Args: { p_application_id: string }
        Returns: undefined
      }
      admin_get_rental_application_details: {
        Args: { p_application_id: string }
        Returns: {
          admin_notes: string
          applicant_email: string
          applicant_name: string
          applicant_phone: string
          applicant_profile_details: Json
          application_data: Json
          application_id: string
          assigned_admin_email: string
          assigned_admin_id: string
          assigned_admin_name: string
          interaction_id: string
          interaction_original_status: Database["public"]["Enums"]["interaction_status_enum"]
          interaction_visit_completed_at: string
          interaction_visit_scheduled_for: string
          landlord_email: string
          landlord_name: string
          landlord_phone: string
          landlord_user_id: string
          property_address: string
          property_city: string
          property_id: string
          property_listing_type: Database["public"]["Enums"]["listing_type_enum"]
          property_locality: string
          property_pincode: number
          property_price: number
          property_type: Database["public"]["Enums"]["property_type_enum"]
          status: Database["public"]["Enums"]["rental_application_status_enum"]
          status_updated_at: string
          submitted_at: string
          updated_at: string
          user_id: string
        }[]
      }
      admin_get_rental_applications: {
        Args: {
          p_applicant_user_id_filter?: string
          p_assigned_admin_id_filter?: string
          p_landlord_user_id_filter?: string
          p_limit?: number
          p_offset?: number
          p_property_id_filter?: string
          p_search_term?: string
          p_sort_by?: string
          p_sort_direction?: string
          p_status_filter?: Database["public"]["Enums"]["rental_application_status_enum"][]
          p_submitted_at_end?: string
          p_submitted_at_start?: string
        }
        Returns: {
          applicant_email: string
          applicant_name: string
          applicant_phone: string
          applicant_user_id: string
          application_data: Json
          application_id: string
          application_status: Database["public"]["Enums"]["rental_application_status_enum"]
          assigned_admin_id: string
          assigned_admin_name: string
          landlord_name: string
          landlord_user_id: string
          property_address: string
          property_city: string
          property_id: string
          property_locality: string
          status_updated_at: string
          submitted_at: string
          total_count: number
        }[]
      }
      admin_self_assign_rental_application: {
        Args: { p_application_id: string }
        Returns: undefined
      }
      admin_unassign_rental_application: {
        Args: { p_application_id: string }
        Returns: undefined
      }
      admin_update_rental_application_status: {
        Args: {
          p_admin_note?: string
          p_application_id: string
          p_new_status: Database["public"]["Enums"]["rental_application_status_enum"]
        }
        Returns: undefined
      }
      assign_interaction_to_tenant_telecaller_admin: {
        Args: { p_interaction_id: string; p_target_admin_id: string }
        Returns: undefined
      }
      assign_pending_sales_visits_admin: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      assign_property_to_marketer_admin: {
        Args: { p_property_id: string; p_target_admin_id: string }
        Returns: undefined
      }
      assign_property_to_owner_telecaller_admin: {
        Args: { p_property_id: string; p_target_admin_id: string }
        Returns: undefined
      }
      assign_service_to_vendor_admin: {
        Args: { p_service_id_input: number; p_vendor_id_input: string }
        Returns: undefined
      }
      assign_ticket_admin: {
        Args: { p_target_admin_id: string; p_ticket_id: number }
        Returns: undefined
      }
      assign_ticket_to_self_telecaller: {
        Args: { p_ticket_id: number }
        Returns: undefined
      }
      assign_ticket_to_vendor_admin: {
        Args: { p_ticket_id: number; p_vendor_id: string }
        Returns: undefined
      }
      auto_assign_marketing_tasks_cron_worker: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      check_user_can_access_ticket: {
        Args: { p_ticket_id: number; p_user_id?: string }
        Returns: boolean
      }
      check_user_is_property_submitter: {
        Args: { p_property_id: string; p_user_id?: string }
        Returns: boolean
      }
      check_user_is_property_tenant: {
        Args: { p_property_id: string; p_user_id?: string }
        Returns: boolean
      }
      complete_purchase: {
        Args: { p_razorpay_order_id: string }
        Returns: undefined
      }
      create_management_plan_admin: {
        Args: {
          p_description?: string
          p_is_active?: boolean
          p_name: string
          p_percentage: number
        }
        Returns: string
      }
      create_rent_record_admin: {
        Args: {
          p_amount_due: number
          p_due_date: string
          p_notes?: string
          p_period_end_date: string
          p_period_start_date: string
          p_property_id: string
        }
        Returns: string
      }
      create_service_admin: {
        Args: {
          p_category?: Database["public"]["Enums"]["service_category_enum"]
          p_description?: string
          p_service_name: string
        }
        Returns: number
      }
      create_ticket_customer: {
        Args: {
          p_category: Database["public"]["Enums"]["ticket_category_enum"]
          p_description: string
          p_priority?: Database["public"]["Enums"]["ticket_priority_enum"]
          p_property_id: string
          p_subject: string
        }
        Returns: number
      }
      create_transaction_customer: {
        Args: { p_plan_id: string; p_razorpay_order_id: string }
        Returns: string
      }
      create_upcoming_rent_records_admin: {
        Args: Record<PropertyKey, never>
        Returns: {
          created_record_count: number
          processed_eligible_property_count: number
          skipped_existing_count: number
          skipped_no_tenant_count: number
        }[]
      }
      create_vendor_admin: {
        Args: {
          p_address?: string
          p_company_name: string
          p_contact_name?: string
          p_email?: string
          p_notes?: string
          p_phone?: string
          p_service_ids?: number[]
          p_status?: Database["public"]["Enums"]["vendor_status_enum"]
        }
        Returns: string
      }
      current_user_has_role: {
        Args: { p_role: Database["public"]["Enums"]["admin_role_enum"] }
        Returns: boolean
      }
      current_user_is_admin: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
      customer_get_my_rental_applications: {
        Args: { p_limit?: number; p_offset?: number }
        Returns: {
          application_id: string
          application_status: Database["public"]["Enums"]["rental_application_status_enum"]
          landlord_name: string
          property_address: string
          property_city: string
          property_id: string
          property_locality: string
          property_main_image_url: string
          property_name: string
          status_updated_at: string
          submitted_at: string
          total_count: number
        }[]
      }
      customer_get_rental_application_details: {
        Args: { p_application_id: string }
        Returns: {
          admin_notes_for_customer: string
          application_data: Json
          application_id: string
          application_status: Database["public"]["Enums"]["rental_application_status_enum"]
          landlord_email: string
          landlord_name: string
          landlord_phone: string
          landlord_user_id: string
          property_address: string
          property_advance_amount: number
          property_city: string
          property_id: string
          property_listing_type: Database["public"]["Enums"]["listing_type_enum"]
          property_locality: string
          property_main_image_url: string
          property_name: string
          property_pincode: number
          property_price: number
          status_updated_at: string
          submitted_at: string
        }[]
      }
      customer_submit_rental_application: {
        Args: {
          p_application_data: Json
          p_interaction_id: string
          p_property_id: string
        }
        Returns: string
      }
      customer_withdraw_rental_application: {
        Args: { p_application_id: string }
        Returns: undefined
      }
      deactivate_admin: {
        Args: { p_user_id: string }
        Returns: undefined
      }
      delete_customer_document_admin: {
        Args: { p_document_id: string }
        Returns: undefined
      }
      delete_property_admin: {
        Args: { p_property_id: string }
        Returns: undefined
      }
      delete_property_document_admin: {
        Args: { p_document_id: string }
        Returns: undefined
      }
      delete_property_image_admin: {
        Args: { p_image_id: string }
        Returns: undefined
      }
      delete_property_image_customer: {
        Args: { p_image_id: string; p_property_id: string }
        Returns: undefined
      }
      delete_rent_payment_admin: {
        Args: { p_payment_id: string }
        Returns: undefined
      }
      delete_rent_record_admin: {
        Args: { p_rent_record_id: string }
        Returns: undefined
      }
      delete_service_admin: {
        Args: { p_service_id: number }
        Returns: undefined
      }
      delete_ticket_comment_admin: {
        Args: { p_comment_id: number }
        Returns: undefined
      }
      delete_ticket_image_admin: {
        Args: { p_image_id: string }
        Returns: undefined
      }
      delete_vendor_admin: {
        Args: { p_vendor_id: string }
        Returns: undefined
      }
      edit_property_image_customer: {
        Args: {
          p_description?: string
          p_display_order?: number
          p_image_id: string
          p_is_internal_image?: boolean
          p_property_id: string
        }
        Returns: undefined
      }
      get_admin_details: {
        Args: { p_admin_user_id: string }
        Returns: {
          auth_user_created_at: string
          created_at: string
          email: string
          full_name: string
          is_active: boolean
          phone: string
          roles: Database["public"]["Enums"]["admin_role_enum"][]
          served_pincodes: number[]
          updated_at: string
          user_id: string
        }[]
      }
      get_all_customer_interactions_admin: {
        Args: {
          p_assigned_sales_admin_id_filter?: string
          p_assigned_tt_admin_id_filter?: string
          p_customer_search?: string
          p_customer_user_id_filter?: string
          p_interaction_statuses?: Database["public"]["Enums"]["interaction_status_enum"][]
          p_limit?: number
          p_offset?: number
          p_property_id_filter?: string
          p_property_search?: string
          p_scheduled_for_end?: string
          p_scheduled_for_start?: string
        }
        Returns: {
          admin_notes: string
          assigned_sales_admin_id: string
          assigned_sales_admin_name: string
          assigned_tenant_telecaller_id: string
          assigned_tenant_telecaller_name: string
          created_at: string
          customer_email: string
          customer_name: string
          customer_phone: string
          customer_user_id: string
          interaction_id: string
          interaction_status: Database["public"]["Enums"]["interaction_status_enum"]
          property_address: string
          property_admin_status: Database["public"]["Enums"]["property_admin_status_enum"]
          property_id: string
          property_locality: string
          property_pincode: number
          scheduled_for: string
          total_count: number
          updated_at: string
          visited_at: string
        }[]
      }
      get_all_transactions_admin: {
        Args: {
          p_created_at_end?: string
          p_created_at_start?: string
          p_customer_user_id_filter?: string
          p_limit?: number
          p_offset?: number
          p_plan_id_filter?: string
          p_razorpay_order_id_filter?: string
          p_statuses_filter?: string[]
        }
        Returns: {
          admin_notes: string
          amount: number
          created_at: string
          customer_email: string
          customer_name: string
          customer_phone: string
          customer_user_id: string
          error_message: string
          plan_id: string
          plan_name: string
          razorpay_order_id: string
          razorpay_payment_id: string
          razorpay_signature: string
          status: string
          total_count: number
          transaction_id: string
          updated_at: string
        }[]
      }
      get_all_visit_plans_admin: {
        Args: { p_is_active_filter?: boolean }
        Returns: {
          created_at: string
          description: string
          is_active: boolean
          name: string
          plan_id: string
          price: number
          updated_at: string
          visits: number
        }[]
      }
      get_assignable_marketing_properties_admin: {
        Args: {
          p_city_filter?: string
          p_limit?: number
          p_offset?: number
          p_pincode_filter?: number
        }
        Returns: {
          address: string
          city: string
          locality: string
          owner_verified_at: string
          pincode: number
          property_id: string
          submitter_name: string
          total_count: number
        }[]
      }
      get_assignable_owner_contact_properties_admin: {
        Args: {
          p_city_filter?: string
          p_limit?: number
          p_offset?: number
          p_pincode_filter?: number
        }
        Returns: {
          address: string
          city: string
          locality: string
          pincode: number
          property_id: string
          submitted_at: string
          submitter_name: string
          submitter_phone: string
          total_count: number
        }[]
      }
      get_assignable_tenant_contact_interactions_admin: {
        Args: {
          p_customer_search_term?: string
          p_limit?: number
          p_offset?: number
          p_property_id_filter?: string
        }
        Returns: {
          customer_email: string
          customer_name: string
          customer_phone: string
          customer_user_id: string
          interaction_created_at: string
          interaction_id: string
          property_address: string
          property_id: string
          property_locality: string
          requested_visit_time: string
          total_count: number
        }[]
      }
      get_customer_full_details_admin: {
        Args: { p_customer_user_id: string }
        Returns: {
          auth_created_at: string
          customer_documents: Json
          customer_updated_at: string
          email: string
          expiry_date: string
          full_name: string
          interactions: Json
          landlord_rent_records: Json
          owned_properties: Json
          phone: string
          profile_details: Json
          raised_tickets: Json
          tenant_in_properties: Json
          tenant_rent_records: Json
          transactions: Json
          user_id: string
          visit_balance: number
        }[]
      }
      get_dashboard_stats_admin: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      get_full_property_details_admin: {
        Args: { p_property_id_input: string }
        Returns: {
          address: string
          admin_notes: string
          admin_status: Database["public"]["Enums"]["property_admin_status_enum"]
          advance_amount: number
          area: number
          area_unit: Database["public"]["Enums"]["area_unit_enum"]
          availability_status: Database["public"]["Enums"]["availability_status_enum"]
          can_reachout: boolean
          city: string
          created_at: string
          customer_interactions: Json
          description: string
          details: Json
          images: Json
          inventory_details: Json
          is_exclusive: boolean
          is_featured: boolean
          is_listed: boolean
          latitude: number
          listing_type: Database["public"]["Enums"]["listing_type_enum"]
          locality: string
          longitude: number
          management_plan: Json
          marketing_assignment: Json
          nearest_busstop: number
          nearest_gym: number
          nearest_hospital: number
          nearest_park: number
          nearest_school: number
          nearest_swimmingpool: number
          owner_contact_assignment: Json
          pincode: number
          price: number
          property_documents: Json
          property_id: string
          property_type: Database["public"]["Enums"]["property_type_enum"]
          proximity_unit: Database["public"]["Enums"]["proximity_unit_enum"]
          rent_due_day: number
          rent_records: Json
          submitted_at: string
          submitter: Json
          submitter_notes: string
          submitter_type: Database["public"]["Enums"]["submitter_type_enum"]
          tenant: Json
          tickets: Json
          updated_at: string
          year_built: number
          youtube_url: string
        }[]
      }
      get_management_plan_details_admin: {
        Args: { p_plan_id_input: string }
        Returns: {
          created_at: string
          description: string
          is_active: boolean
          name: string
          percentage: number
          plan_id: string
          updated_at: string
        }[]
      }
      get_my_admin_roles: {
        Args: Record<PropertyKey, never>
        Returns: Database["public"]["Enums"]["admin_role_enum"][]
      }
      get_my_interaction_summary_customer: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      get_my_interactions_customer: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_statuses?: Database["public"]["Enums"]["interaction_status_enum"][]
        }
        Returns: {
          advance_amount: number
          assigned_sales_admin_email: string
          assigned_sales_admin_name: string
          assigned_sales_admin_phone: string
          city: string
          created_at: string
          interaction_id: string
          interaction_status: Database["public"]["Enums"]["interaction_status_enum"]
          listing_type: Database["public"]["Enums"]["listing_type_enum"]
          locality: string
          pincode: number
          price: number
          property_id: string
          property_main_image_url: string
          property_name: string
          property_type: Database["public"]["Enums"]["property_type_enum"]
          scheduled_for: string
          total_count: number
          updated_at: string
          visited_at: string
        }[]
      }
      get_my_occupied_properties_customer: {
        Args: { p_limit?: number; p_offset?: number }
        Returns: {
          address: string
          advance_amount: number
          area: number
          area_unit: Database["public"]["Enums"]["area_unit_enum"]
          city: string
          description: string
          details: Json
          landlord_email: string
          landlord_name: string
          landlord_phone: string
          landlord_user_id: string
          latest_rent_amount_due: number
          latest_rent_due_date: string
          latest_rent_record_id: string
          latest_rent_status: Database["public"]["Enums"]["rent_status_enum"]
          listing_type: Database["public"]["Enums"]["listing_type_enum"]
          locality: string
          monthly_rent: number
          pincode: number
          property_id: string
          property_images: Json
          property_type: Database["public"]["Enums"]["property_type_enum"]
          rent_due_day: number
          total_count: number
          updated_at: string
          year_built: number
          youtube_url: string
        }[]
      }
      get_my_properties_customer: {
        Args: { p_limit?: number; p_offset?: number }
        Returns: {
          address: string
          admin_status: Database["public"]["Enums"]["property_admin_status_enum"]
          advance_amount: number
          area: number
          area_unit: Database["public"]["Enums"]["area_unit_enum"]
          availability_status: Database["public"]["Enums"]["availability_status_enum"]
          can_reachout: boolean
          city: string
          created_at: string
          description: string
          details: Json
          interaction_count: number
          inventory_details: Json
          is_exclusive: boolean
          is_featured: boolean
          is_listed: boolean
          latitude: number
          listing_type: Database["public"]["Enums"]["listing_type_enum"]
          locality: string
          longitude: number
          management_plan_id: string
          management_plan_name: string
          nearest_busstop: number
          nearest_gym: number
          nearest_hospital: number
          nearest_park: number
          nearest_school: number
          nearest_swimmingpool: number
          pincode: number
          price: number
          property_id: string
          property_images: Json
          property_type: Database["public"]["Enums"]["property_type_enum"]
          proximity_unit: Database["public"]["Enums"]["proximity_unit_enum"]
          submitted_at: string
          submitter_notes: string
          submitter_type: Database["public"]["Enums"]["submitter_type_enum"]
          tenant_info: Json
          total_count: number
          updated_at: string
          year_built: number
          youtube_url: string
        }[]
      }
      get_my_property_with_id_customer: {
        Args: { p_property_id_input: string }
        Returns: {
          address: string
          admin_status: Database["public"]["Enums"]["property_admin_status_enum"]
          advance_amount: number
          area: number
          area_unit: Database["public"]["Enums"]["area_unit_enum"]
          availability_status: Database["public"]["Enums"]["availability_status_enum"]
          can_reachout: boolean
          city: string
          created_at: string
          description: string
          details: Json
          interaction_count: number
          inventory_details: Json
          is_exclusive: boolean
          is_featured: boolean
          is_listed: boolean
          latitude: number
          listing_type: Database["public"]["Enums"]["listing_type_enum"]
          locality: string
          longitude: number
          management_plan_id: string
          management_plan_name: string
          nearest_busstop: number
          nearest_gym: number
          nearest_hospital: number
          nearest_park: number
          nearest_school: number
          nearest_swimmingpool: number
          pincode: number
          price: number
          property_id: string
          property_images: Json
          property_type: Database["public"]["Enums"]["property_type_enum"]
          proximity_unit: Database["public"]["Enums"]["proximity_unit_enum"]
          submitted_at: string
          submitter_notes: string
          submitter_type: Database["public"]["Enums"]["submitter_type_enum"]
          tenant_info: Json
          updated_at: string
          year_built: number
          youtube_url: string
        }[]
      }
      get_my_raised_tickets_customer: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_status_filter?: Database["public"]["Enums"]["ticket_status_enum"][]
        }
        Returns: {
          assigned_support_admin_name: string
          category: Database["public"]["Enums"]["ticket_category_enum"]
          closed_at: string
          created_at: string
          priority: Database["public"]["Enums"]["ticket_priority_enum"]
          property_address: string
          property_city: string
          property_id: string
          property_locality: string
          resolved_at: string
          status: Database["public"]["Enums"]["ticket_status_enum"]
          subject: string
          ticket_id: number
          total_count: number
          updated_at: string
        }[]
      }
      get_my_rent_dues_customer: {
        Args: { p_limit?: number; p_offset?: number }
        Returns: {
          amount_due: number
          amount_paid: number
          due_date: string
          landlord_email: string
          landlord_name: string
          landlord_phone: string
          landlord_user_id: string
          period_end_date: string
          period_start_date: string
          property_address: string
          property_city: string
          property_id: string
          property_locality: string
          rent_record_id: string
          status: Database["public"]["Enums"]["rent_status_enum"]
          total_count: number
        }[]
      }
      get_my_sales_visits_admin: {
        Args: { p_visit_date?: string }
        Returns: {
          customer_email: string
          customer_name: string
          customer_phone: string
          customer_user_id: string
          property_visits: Json
          visit_assignment_id: string
        }[]
      }
      get_my_transactions_customer: {
        Args: { p_limit?: number; p_offset?: number }
        Returns: {
          amount: number
          created_at: string
          error_message: string
          plan_id: string
          plan_name: string
          razorpay_order_id: string
          razorpay_payment_id: string
          status: string
          total_count: number
          transaction_id: string
          updated_at: string
        }[]
      }
      get_occupied_properties_rent_status_report_admin: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_search?: string
          p_rent_status_filter?: Database["public"]["Enums"]["rent_status_enum"]
          p_tenant_search?: string
        }
        Returns: {
          last_payment_date_for_latest_record: string
          latest_rent_amount_due: number
          latest_rent_amount_paid: number
          latest_rent_record_due_date: string
          latest_rent_record_id: string
          latest_rent_record_status: Database["public"]["Enums"]["rent_status_enum"]
          property_address: string
          property_city: string
          property_id: string
          property_locality: string
          property_pincode: number
          property_rent_due_day: number
          tenant_email: string
          tenant_name: string
          tenant_phone: string
          tenant_user_id: string
          total_count: number
        }[]
      }
      get_properties_admin: {
        Args: {
          p_admin_statuses?: Database["public"]["Enums"]["property_admin_status_enum"][]
          p_city?: string
          p_is_exclusive?: boolean
          p_is_featured?: boolean
          p_is_listed_filter?: boolean
          p_limit?: number
          p_listing_types?: Database["public"]["Enums"]["listing_type_enum"][]
          p_management_plan_id?: string
          p_marketing_assigned_to_admin_id?: string
          p_marketing_assignment_status?: string
          p_offset?: number
          p_owner_contact_assigned_to_admin_id?: string
          p_owner_contact_assignment_status?: string
          p_pincodes?: number[]
          p_price_max?: number
          p_price_min?: number
          p_property_search?: string
          p_property_types?: Database["public"]["Enums"]["property_type_enum"][]
          p_sort_by?: string
          p_sort_direction?: string
          p_submitter_id?: string
          p_tenant_id?: string
        }
        Returns: {
          address: string
          admin_notes: string
          admin_status: Database["public"]["Enums"]["property_admin_status_enum"]
          advance_amount: number
          area: number
          area_unit: Database["public"]["Enums"]["area_unit_enum"]
          availability_status: Database["public"]["Enums"]["availability_status_enum"]
          can_reachout: boolean
          city: string
          created_at: string
          description: string
          details: Json
          inventory_details: Json
          is_exclusive: boolean
          is_featured: boolean
          is_listed: boolean
          latitude: number
          listing_type: Database["public"]["Enums"]["listing_type_enum"]
          locality: string
          longitude: number
          management_plan_info: Json
          marketing_assigned_admin_id: string
          marketing_assigned_admin_name: string
          marketing_assigned_at: string
          owner_contact_assigned_admin_id: string
          owner_contact_assigned_admin_name: string
          owner_contact_assigned_at: string
          pincode: number
          price: number
          property_id: string
          property_images: Json
          property_name: string
          property_type: Database["public"]["Enums"]["property_type_enum"]
          rent_due_day: number
          submitted_at: string
          submitter_info: Json
          submitter_notes: string
          submitter_type: Database["public"]["Enums"]["submitter_type_enum"]
          tenant_info: Json
          total_count: number
          updated_at: string
          year_built: number
          youtube_url: string
        }[]
      }
      get_properties_customer: {
        Args: {
          p_area_max?: number
          p_area_min?: number
          p_area_unit?: Database["public"]["Enums"]["area_unit_enum"]
          p_building_types?: Database["public"]["Enums"]["building_type_enum"][]
          p_city?: string
          p_facing_directions?: Database["public"]["Enums"]["direction_enum"][]
          p_furnished_statuses?: Database["public"]["Enums"]["furnished_status_enum"][]
          p_house_types?: Database["public"]["Enums"]["house_type_enum"][]
          p_is_featured?: boolean
          p_land_types?: Database["public"]["Enums"]["land_type_enum"][]
          p_limit?: number
          p_listing_types?: Database["public"]["Enums"]["listing_type_enum"][]
          p_location_search?: string
          p_num_bedrooms_max?: number
          p_num_bedrooms_min?: number
          p_offset?: number
          p_pincodes?: number[]
          p_price_max?: number
          p_price_min?: number
          p_property_types?: Database["public"]["Enums"]["property_type_enum"][]
          p_sort_by?: string
          p_sort_direction?: string
        }
        Returns: {
          advance_amount: number
          area: number
          area_unit: Database["public"]["Enums"]["area_unit_enum"]
          city: string
          created_at: string
          description: string
          details: Json
          interaction_id: string
          interaction_status: Database["public"]["Enums"]["interaction_status_enum"]
          is_featured: boolean
          is_in_wishlist: boolean
          latitude: number
          listing_type: Database["public"]["Enums"]["listing_type_enum"]
          locality: string
          longitude: number
          nearest_busstop: number
          nearest_gym: number
          nearest_hospital: number
          nearest_park: number
          nearest_school: number
          nearest_swimmingpool: number
          pincode: number
          price: number
          property_id: string
          property_images: Json
          property_name: string
          property_type: Database["public"]["Enums"]["property_type_enum"]
          proximity_unit: Database["public"]["Enums"]["proximity_unit_enum"]
          total_count: number
          updated_at: string
          year_built: number
          youtube_url: string
        }[]
      }
      get_property_details_admin: {
        Args: { p_property_id_input: string }
        Returns: {
          address: string
          admin_notes: string
          admin_status: Database["public"]["Enums"]["property_admin_status_enum"]
          advance_amount: number
          area: number
          area_unit: Database["public"]["Enums"]["area_unit_enum"]
          availability_status: Database["public"]["Enums"]["availability_status_enum"]
          can_reachout: boolean
          city: string
          created_at: string
          description: string
          details: Json
          inventory_details: Json
          is_exclusive: boolean
          is_featured: boolean
          is_listed: boolean
          latitude: number
          listing_type: Database["public"]["Enums"]["listing_type_enum"]
          locality: string
          longitude: number
          management_plan_info: Json
          marketing_assignment: Json
          nearest_busstop: number
          nearest_gym: number
          nearest_hospital: number
          nearest_park: number
          nearest_school: number
          nearest_swimmingpool: number
          owner_contact_assignment: Json
          pincode: number
          price: number
          property_documents: Json
          property_id: string
          property_images: Json
          property_name: string
          property_type: Database["public"]["Enums"]["property_type_enum"]
          proximity_unit: Database["public"]["Enums"]["proximity_unit_enum"]
          rent_due_day: number
          submitted_at: string
          submitter_info: Json
          submitter_notes: string
          submitter_type: Database["public"]["Enums"]["submitter_type_enum"]
          tenant_info: Json
          updated_at: string
          year_built: number
          youtube_url: string
        }[]
      }
      get_property_from_id_customer: {
        Args: { p_requested_property_id: string }
        Returns: {
          address: string
          advance_amount: number
          area: number
          area_unit: Database["public"]["Enums"]["area_unit_enum"]
          city: string
          created_at: string
          description: string
          details: Json
          interaction_id: string
          interaction_status: Database["public"]["Enums"]["interaction_status_enum"]
          is_featured: boolean
          is_in_wishlist: boolean
          latitude: number
          listing_type: Database["public"]["Enums"]["listing_type_enum"]
          locality: string
          longitude: number
          nearest_busstop: number
          nearest_gym: number
          nearest_hospital: number
          nearest_park: number
          nearest_school: number
          nearest_swimmingpool: number
          pincode: number
          price: number
          property_id: string
          property_images: Json
          property_name: string
          property_type: Database["public"]["Enums"]["property_type_enum"]
          proximity_unit: Database["public"]["Enums"]["proximity_unit_enum"]
          submitter_info: Json
          updated_at: string
          year_built: number
          youtube_url: string
        }[]
      }
      get_property_payment_history_landlord: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_id_input: string
        }
        Returns: {
          amount_paid: number
          payment_date: string
          payment_id: string
          payment_method: string
          rent_due_date: string
          rent_period_end_date: string
          rent_period_start_date: string
          rent_record_id: string
          tenant_email: string
          tenant_name: string
          tenant_phone: string
          tenant_user_id: string
          total_count: number
          transaction_ref: string
        }[]
      }
      get_property_rent_dues_landlord: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_id_filter?: string
        }
        Returns: {
          amount_due: number
          amount_paid: number
          due_date: string
          period_end_date: string
          period_start_date: string
          property_address: string
          property_city: string
          property_id: string
          property_locality: string
          rent_record_id: string
          status: Database["public"]["Enums"]["rent_status_enum"]
          tenant_email: string
          tenant_name: string
          tenant_phone: string
          tenant_user_id: string
          total_count: number
        }[]
      }
      get_property_tickets_landlord: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_id_filter?: string
          p_status_filter?: Database["public"]["Enums"]["ticket_status_enum"][]
        }
        Returns: {
          assigned_support_admin_name: string
          category: Database["public"]["Enums"]["ticket_category_enum"]
          closed_at: string
          created_at: string
          priority: Database["public"]["Enums"]["ticket_priority_enum"]
          property_address: string
          property_city: string
          property_id: string
          property_locality: string
          raised_by_user_id: string
          raiser_email: string
          raiser_name: string
          raiser_phone: string
          resolved_at: string
          status: Database["public"]["Enums"]["ticket_status_enum"]
          subject: string
          ticket_id: number
          total_count: number
          updated_at: string
        }[]
      }
      get_rent_record_details_admin: {
        Args: { p_rent_record_id_input: string }
        Returns: {
          amount_due: number
          amount_paid: number
          created_at: string
          due_date: string
          landlord_name: string
          landlord_phone: string
          landlord_user_id: string
          notes: string
          payments: Json
          period_end_date: string
          period_start_date: string
          property_address: string
          property_id: string
          rent_record_id: string
          status: Database["public"]["Enums"]["rent_status_enum"]
          tenant_name: string
          tenant_phone: string
          tenant_user_id: string
          updated_at: string
        }[]
      }
      get_sales_team_performance_admin: {
        Args: {
          p_admin_id_filter?: string
          p_end_date?: string
          p_start_date?: string
        }
        Returns: {
          admin_id: string
          admin_name: string
          total_interactions_cancelled_by_sales: number
          total_interactions_completed: number
          total_interactions_scheduled: number
          total_visit_assignments: number
        }[]
      }
      get_telecalling_owner_team_performance_admin: {
        Args: {
          p_admin_id_filter?: string
          p_end_date?: string
          p_start_date?: string
        }
        Returns: {
          admin_id: string
          admin_name: string
          avg_docs_per_verified_property: number
          currently_assigned_pending_count: number
          properties_verified_count: number
        }[]
      }
      get_ticket_details_admin: {
        Args: { p_ticket_id_input: number }
        Returns: {
          assigned_support_admin_id: string
          assigned_support_admin_name: string
          assigned_to_vendor_id: string
          assigned_vendor_name: string
          assigned_vendor_phone: string
          category: Database["public"]["Enums"]["ticket_category_enum"]
          closed_at: string
          comments: Json
          created_at: string
          description: string
          images: Json
          priority: Database["public"]["Enums"]["ticket_priority_enum"]
          property_address: string
          property_id: string
          property_locality: string
          raised_by_user_id: string
          raiser_email: string
          raiser_name: string
          raiser_phone: string
          resolution_notes: string
          resolved_at: string
          status: Database["public"]["Enums"]["ticket_status_enum"]
          subject: string
          ticket_id: number
          updated_at: string
        }[]
      }
      get_ticket_details_customer: {
        Args: { p_ticket_id_input: number }
        Returns: {
          assigned_support_admin_name: string
          category: Database["public"]["Enums"]["ticket_category_enum"]
          closed_at: string
          comments: Json
          created_at: string
          description: string
          images: Json
          priority: Database["public"]["Enums"]["ticket_priority_enum"]
          property_address: string
          property_city: string
          property_id: string
          property_locality: string
          raised_by_user_id: string
          raiser_email: string
          raiser_name: string
          raiser_phone: string
          resolution_notes: string
          resolved_at: string
          status: Database["public"]["Enums"]["ticket_status_enum"]
          subject: string
          ticket_id: number
          updated_at: string
        }[]
      }
      get_ticket_handling_performance_admin: {
        Args: {
          p_admin_id_filter?: string
          p_end_date?: string
          p_role_filter?: Database["public"]["Enums"]["admin_role_enum"]
          p_start_date?: string
        }
        Returns: {
          admin_id: string
          admin_name: string
          avg_resolution_time_hours: number
          roles: Database["public"]["Enums"]["admin_role_enum"][]
          tickets_assigned_in_period: number
          tickets_closed_in_period: number
          tickets_resolved_in_period: number
        }[]
      }
      get_vendor_details_admin: {
        Args: { p_vendor_id_input: string }
        Returns: {
          address: string
          company_name: string
          contact_name: string
          created_at: string
          email: string
          notes: string
          phone: string
          services: Json
          status: Database["public"]["Enums"]["vendor_status_enum"]
          updated_at: string
          vendor_id: string
        }[]
      }
      get_visit_plans_customer: {
        Args: Record<PropertyKey, never>
        Returns: {
          description: string
          name: string
          plan_id: string
          price: number
          visits: number
        }[]
      }
      get_visit_status_customer: {
        Args: Record<PropertyKey, never>
        Returns: {
          expiry_date: string
          visit_balance: number
        }[]
      }
      insert_property_admin: {
        Args: {
          p_address: string
          p_admin_notes?: string
          p_admin_status?: Database["public"]["Enums"]["property_admin_status_enum"]
          p_advance_amount?: number
          p_area: number
          p_area_unit: Database["public"]["Enums"]["area_unit_enum"]
          p_availability_status?: Database["public"]["Enums"]["availability_status_enum"]
          p_can_reachout?: boolean
          p_city: string
          p_description?: string
          p_details: Json
          p_inventory_details?: Json
          p_is_exclusive?: boolean
          p_is_featured?: boolean
          p_is_listed?: boolean
          p_latitude?: number
          p_listing_type: Database["public"]["Enums"]["listing_type_enum"]
          p_locality: string
          p_longitude?: number
          p_management_plan_id?: string
          p_nearest_busstop?: number
          p_nearest_gym?: number
          p_nearest_hospital?: number
          p_nearest_park?: number
          p_nearest_school?: number
          p_nearest_swimmingpool?: number
          p_pincode: number
          p_price: number
          p_property_type: Database["public"]["Enums"]["property_type_enum"]
          p_proximity_unit?: Database["public"]["Enums"]["proximity_unit_enum"]
          p_rent_due_day?: number
          p_submitter?: string
          p_submitter_notes?: string
          p_submitter_type?: Database["public"]["Enums"]["submitter_type_enum"]
          p_tenant?: string
          p_year_built?: number
          p_youtube_url?: string
        }
        Returns: string
      }
      insert_property_customer: {
        Args: {
          p_address: string
          p_advance_amount?: number
          p_area: number
          p_area_unit: Database["public"]["Enums"]["area_unit_enum"]
          p_availability_status?: Database["public"]["Enums"]["availability_status_enum"]
          p_can_reachout?: boolean
          p_city: string
          p_description?: string
          p_details: Json
          p_inventory_details?: Json
          p_is_exclusive?: boolean
          p_latitude?: number
          p_listing_type: Database["public"]["Enums"]["listing_type_enum"]
          p_locality: string
          p_longitude?: number
          p_management_plan_id?: string
          p_nearest_busstop?: number
          p_nearest_gym?: number
          p_nearest_hospital?: number
          p_nearest_park?: number
          p_nearest_school?: number
          p_nearest_swimmingpool?: number
          p_pincode: number
          p_price: number
          p_property_type: Database["public"]["Enums"]["property_type_enum"]
          p_proximity_unit?: Database["public"]["Enums"]["proximity_unit_enum"]
          p_rent_due_day?: number
          p_submitter_notes?: string
          p_submitter_type: Database["public"]["Enums"]["submitter_type_enum"]
          p_year_built?: number
          p_youtube_url?: string
        }
        Returns: string
      }
      insert_visit_plan_admin: {
        Args: {
          p_description: string
          p_is_active?: boolean
          p_name: string
          p_price: number
          p_visits: number
        }
        Returns: string
      }
      list_admins: {
        Args: {
          p_is_active_filter?: boolean
          p_limit?: number
          p_offset?: number
          p_role_filter?: Database["public"]["Enums"]["admin_role_enum"]
          p_search_term?: string
        }
        Returns: {
          created_at: string
          email: string
          full_name: string
          is_active: boolean
          phone: string
          roles: Database["public"]["Enums"]["admin_role_enum"][]
          served_pincodes: number[]
          total_count: number
          updated_at: string
          user_id: string
        }[]
      }
      list_management_plans_admin: {
        Args: {
          p_is_active_filter?: boolean
          p_limit?: number
          p_offset?: number
        }
        Returns: {
          created_at: string
          description: string
          is_active: boolean
          name: string
          percentage: number
          plan_id: string
          total_count: number
          updated_at: string
        }[]
      }
      list_management_plans_customer: {
        Args: Record<PropertyKey, never>
        Returns: {
          description: string
          name: string
          percentage: number
          plan_id: string
        }[]
      }
      list_rent_records_admin: {
        Args: {
          p_due_date_end?: string
          p_due_date_start?: string
          p_landlord_user_id_filter?: string
          p_limit?: number
          p_offset?: number
          p_property_id_filter?: string
          p_status_filter?: Database["public"]["Enums"]["rent_status_enum"]
          p_tenant_user_id_filter?: string
        }
        Returns: {
          amount_due: number
          amount_paid: number
          created_at: string
          due_date: string
          landlord_email: string
          landlord_name: string
          landlord_phone: string
          landlord_user_id: string
          notes: string
          period_end_date: string
          period_start_date: string
          property_address: string
          property_id: string
          property_locality: string
          rent_record_id: string
          status: Database["public"]["Enums"]["rent_status_enum"]
          tenant_email: string
          tenant_name: string
          tenant_phone: string
          tenant_user_id: string
          total_count: number
          updated_at: string
        }[]
      }
      list_services_admin: {
        Args: {
          p_category_filter?: Database["public"]["Enums"]["service_category_enum"]
          p_limit?: number
          p_offset?: number
          p_search_term?: string
        }
        Returns: {
          category: Database["public"]["Enums"]["service_category_enum"]
          created_at: string
          description: string
          service_id: number
          service_name: string
          total_count: number
        }[]
      }
      list_tickets_admin: {
        Args: {
          p_assigned_support_admin_id_filter?: string
          p_assigned_to_vendor_id_filter?: string
          p_category_filter?: Database["public"]["Enums"]["ticket_category_enum"][]
          p_created_at_end?: string
          p_created_at_start?: string
          p_limit?: number
          p_offset?: number
          p_priority_filter?: Database["public"]["Enums"]["ticket_priority_enum"][]
          p_property_id_filter?: string
          p_raised_by_user_id_filter?: string
          p_search_term?: string
          p_status_filter?: Database["public"]["Enums"]["ticket_status_enum"][]
        }
        Returns: {
          assigned_support_admin_id: string
          assigned_support_admin_name: string
          assigned_to_vendor_id: string
          assigned_vendor_name: string
          category: Database["public"]["Enums"]["ticket_category_enum"]
          closed_at: string
          created_at: string
          priority: Database["public"]["Enums"]["ticket_priority_enum"]
          property_address: string
          property_id: string
          property_locality: string
          raised_by_user_id: string
          raiser_email: string
          raiser_name: string
          raiser_phone: string
          resolved_at: string
          status: Database["public"]["Enums"]["ticket_status_enum"]
          subject: string
          ticket_id: number
          total_count: number
          updated_at: string
        }[]
      }
      list_vendors_admin: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_search_term?: string
          p_service_id_filter?: number
          p_status_filter?: Database["public"]["Enums"]["vendor_status_enum"]
        }
        Returns: {
          company_name: string
          contact_name: string
          email: string
          notes: string
          phone: string
          services_summary: string
          status: Database["public"]["Enums"]["vendor_status_enum"]
          total_count: number
          vendor_id: string
        }[]
      }
      mark_interaction_tenant_verified_admin: {
        Args: {
          p_interaction_id: string
          p_updated_scheduled_for?: string
          p_verification_notes?: string
        }
        Returns: undefined
      }
      mark_interaction_visit_cancelled_sales_admin: {
        Args: { p_cancellation_reason: string; p_interaction_id: string }
        Returns: undefined
      }
      mark_interaction_visit_completed_sales_admin: {
        Args: { p_feedback?: string; p_interaction_id: string }
        Returns: undefined
      }
      mark_property_marketing_verified_admin: {
        Args: { p_marketing_notes?: string; p_property_id: string }
        Returns: undefined
      }
      mark_property_owner_verified_admin: {
        Args: { p_property_id: string; p_verification_notes?: string }
        Returns: undefined
      }
      record_customer_document_upload_admin: {
        Args: {
          p_customer_user_id: string
          p_description?: string
          p_document_type: string
          p_document_url: string
          p_file_name?: string
        }
        Returns: string
      }
      record_property_document_upload_admin: {
        Args: {
          p_description?: string
          p_document_type: string
          p_document_url: string
          p_file_name?: string
          p_property_id: string
        }
        Returns: string
      }
      record_property_image_upload_admin: {
        Args: {
          p_description?: string
          p_display_order?: number
          p_image_url: string
          p_is_internal_image?: boolean
          p_property_id: string
        }
        Returns: string
      }
      record_rent_payment_admin: {
        Args: {
          p_amount: number
          p_notes?: string
          p_paid_by_user_id: string
          p_payment_date?: string
          p_payment_method?: string
          p_rent_record_id: string
          p_transaction_ref?: string
        }
        Returns: string
      }
      record_ticket_image_upload_admin: {
        Args: {
          p_description?: string
          p_image_url: string
          p_ticket_id: number
        }
        Returns: string
      }
      remove_admin_role: {
        Args: {
          p_role_to_remove: Database["public"]["Enums"]["admin_role_enum"]
          p_user_id: string
        }
        Returns: undefined
      }
      remove_interaction_customer: {
        Args: { p_property_id: string }
        Returns: undefined
      }
      remove_service_from_vendor_admin: {
        Args: { p_service_id_input: number; p_vendor_id_input: string }
        Returns: undefined
      }
      request_visit_customer: {
        Args: { p_preferred_date: string; p_property_id: string }
        Returns: string
      }
      search_customers_admin: {
        Args: {
          p_has_active_plan?: boolean
          p_limit?: number
          p_offset?: number
          p_search_term: string
        }
        Returns: {
          created_at: string
          customer_record_updated_at: string
          email: string
          expiry_date: string
          full_name: string
          phone: string
          profile_details: Json
          total_count: number
          user_id: string
          visit_balance: number
        }[]
      }
      self_assign_interaction_for_tenant_contact_admin: {
        Args: { p_interaction_id: string }
        Returns: undefined
      }
      self_assign_property_for_owner_contact_admin: {
        Args: { p_property_id: string }
        Returns: undefined
      }
      set_admin_roles: {
        Args: {
          p_roles: Database["public"]["Enums"]["admin_role_enum"][]
          p_user_id: string
        }
        Returns: undefined
      }
      set_property_listing_status_admin: {
        Args: {
          p_make_listed: boolean
          p_new_admin_status?: Database["public"]["Enums"]["property_admin_status_enum"]
          p_property_id: string
        }
        Returns: undefined
      }
      unassign_interaction_from_tenant_telecaller_admin: {
        Args: { p_interaction_id: string }
        Returns: undefined
      }
      unassign_property_from_marketer_admin: {
        Args: { p_property_id: string }
        Returns: undefined
      }
      unassign_property_from_owner_telecaller_admin: {
        Args: { p_property_id: string }
        Returns: undefined
      }
      unassign_ticket_admin: {
        Args: { p_ticket_id: number }
        Returns: undefined
      }
      update_admin_pincodes: {
        Args: { p_pincodes: number[]; p_user_id: string }
        Returns: undefined
      }
      update_customer_interaction_admin: {
        Args: {
          p_assign_sales_admin_id?: string
          p_assign_tenant_telecaller_id?: string
          p_interaction_id: string
          p_new_admin_notes?: string
          p_new_scheduled_for?: string
          p_new_status?: Database["public"]["Enums"]["interaction_status_enum"]
        }
        Returns: undefined
      }
      update_customer_profile_details_admin: {
        Args: {
          p_customer_user_id: string
          p_full_name?: string
          p_phone?: string
          p_profile_details: Json
        }
        Returns: undefined
      }
      update_customer_visits_admin: {
        Args: {
          p_customer_user_id: string
          p_new_expiry_date: string
          p_new_visit_balance: number
        }
        Returns: undefined
      }
      update_management_plan_admin: {
        Args: {
          p_description?: string
          p_is_active?: boolean
          p_name?: string
          p_percentage?: number
          p_plan_id: string
        }
        Returns: undefined
      }
      update_property_admin: {
        Args: {
          p_address?: string
          p_admin_notes?: string
          p_admin_status?: Database["public"]["Enums"]["property_admin_status_enum"]
          p_advance_amount?: number
          p_area?: number
          p_area_unit?: Database["public"]["Enums"]["area_unit_enum"]
          p_availability_status?: Database["public"]["Enums"]["availability_status_enum"]
          p_can_reachout?: boolean
          p_city?: string
          p_description?: string
          p_details?: Json
          p_inventory_details?: Json
          p_is_exclusive?: boolean
          p_is_featured?: boolean
          p_is_listed?: boolean
          p_latitude?: number
          p_listing_type?: Database["public"]["Enums"]["listing_type_enum"]
          p_locality?: string
          p_longitude?: number
          p_management_plan_id?: string
          p_nearest_busstop?: number
          p_nearest_gym?: number
          p_nearest_hospital?: number
          p_nearest_park?: number
          p_nearest_school?: number
          p_nearest_swimmingpool?: number
          p_pincode?: number
          p_price?: number
          p_property_id: string
          p_property_type?: Database["public"]["Enums"]["property_type_enum"]
          p_proximity_unit?: Database["public"]["Enums"]["proximity_unit_enum"]
          p_rent_due_day?: number
          p_submitter?: string
          p_submitter_notes?: string
          p_submitter_type?: Database["public"]["Enums"]["submitter_type_enum"]
          p_tenant?: string
          p_year_built?: number
          p_youtube_url?: string
        }
        Returns: undefined
      }
      update_property_customer: {
        Args: {
          p_address: string
          p_advance_amount?: number
          p_area: number
          p_area_unit: Database["public"]["Enums"]["area_unit_enum"]
          p_availability_status?: Database["public"]["Enums"]["availability_status_enum"]
          p_can_reachout?: boolean
          p_city: string
          p_description?: string
          p_details: Json
          p_inventory_details?: Json
          p_is_exclusive?: boolean
          p_latitude?: number
          p_listing_type: Database["public"]["Enums"]["listing_type_enum"]
          p_locality: string
          p_longitude?: number
          p_management_plan_id?: string
          p_nearest_busstop?: number
          p_nearest_gym?: number
          p_nearest_hospital?: number
          p_nearest_park?: number
          p_nearest_school?: number
          p_nearest_swimmingpool?: number
          p_pincode: number
          p_price: number
          p_property_id: string
          p_property_type: Database["public"]["Enums"]["property_type_enum"]
          p_proximity_unit?: Database["public"]["Enums"]["proximity_unit_enum"]
          p_rent_due_day?: number
          p_submitter_notes?: string
          p_submitter_type: Database["public"]["Enums"]["submitter_type_enum"]
          p_year_built?: number
          p_youtube_url?: string
        }
        Returns: undefined
      }
      update_property_image_admin: {
        Args: {
          p_description?: string
          p_display_order?: number
          p_image_id: string
          p_is_internal_image?: boolean
        }
        Returns: undefined
      }
      update_rent_record_admin: {
        Args: {
          p_amount_due?: number
          p_amount_paid?: number
          p_due_date?: string
          p_notes?: string
          p_period_end_date?: string
          p_period_start_date?: string
          p_rent_record_id: string
          p_status?: Database["public"]["Enums"]["rent_status_enum"]
        }
        Returns: undefined
      }
      update_service_admin: {
        Args: {
          p_category?: Database["public"]["Enums"]["service_category_enum"]
          p_description?: string
          p_service_id: number
          p_service_name: string
        }
        Returns: undefined
      }
      update_ticket_details_admin: {
        Args: {
          p_category?: Database["public"]["Enums"]["ticket_category_enum"]
          p_description?: string
          p_priority?: Database["public"]["Enums"]["ticket_priority_enum"]
          p_resolution_notes?: string
          p_status?: Database["public"]["Enums"]["ticket_status_enum"]
          p_subject?: string
          p_ticket_id: number
        }
        Returns: undefined
      }
      update_transaction_status: {
        Args: {
          p_error_message?: string
          p_razorpay_order_id: string
          p_razorpay_payment_id?: string
          p_razorpay_signature?: string
          p_status: string
        }
        Returns: undefined
      }
      update_transaction_status_admin: {
        Args: {
          p_admin_notes?: string
          p_new_status: string
          p_transaction_id: string
        }
        Returns: undefined
      }
      update_vendor_admin: {
        Args: {
          p_address?: string
          p_company_name?: string
          p_contact_name?: string
          p_email?: string
          p_notes?: string
          p_phone?: string
          p_status?: Database["public"]["Enums"]["vendor_status_enum"]
          p_vendor_id: string
        }
        Returns: undefined
      }
      update_visit_plan_admin: {
        Args: {
          p_description: string
          p_is_active: boolean
          p_name: string
          p_plan_id: string
          p_price: number
          p_visits: number
        }
        Returns: undefined
      }
      user_is_admin_with_role: {
        Args: {
          p_role: Database["public"]["Enums"]["admin_role_enum"]
          p_user_id: string
        }
        Returns: boolean
      }
    }
    Enums: {
      admin_role_enum:
        | "super-admin"
        | "telecalling-owner-team"
        | "marketing-team"
        | "telecalling-tenant-team"
        | "sales-team"
        | "accounts-team"
      area_unit_enum: "SQ_FT" | "CENTS" | "ACRES"
      availability_status_enum: "UNDER_CONSTRUCTION" | "READY_TO_MOVE"
      building_type_enum:
        | "OFFICE"
        | "WAREHOUSE"
        | "RETAIL"
        | "INDUSTRIAL"
        | "HOSPITALITY"
      direction_enum: "NORTH" | "SOUTH" | "EAST" | "WEST"
      furnished_status_enum:
        | "UNFURNISHED"
        | "SEMI_FURNISHED"
        | "FULLY_FURNISHED"
      house_type_enum: "APARTMENT_FLAT" | "INDEPENDENT_VILLA" | "HOSTEL_PG"
      interaction_status_enum:
        | "WISHLISTED"
        | "VISIT_PENDING"
        | "VISIT_CONFIRMED_PENDING_SALES"
        | "VISIT_SCHEDULED_WITH_SALES"
        | "VISIT_COMPLETED"
        | "VISIT_CANCELLED"
        | "RENTAL_APPLICATION_SUBMITTED"
        | "LEASE_CONVERTED"
      land_type_enum: "RESIDENTIAL" | "COMMERCIAL" | "AGRICULTURAL"
      listing_type_enum: "RENTAL" | "SALE"
      power_backup_enum: "NONE" | "PARTIAL" | "FULL"
      property_admin_status_enum:
        | "SUBMITTED"
        | "OWNER_CONTACT_PENDING"
        | "OWNER_VERIFIED"
        | "MARKETING_VISIT_PENDING"
        | "MARKETING_VERIFIED"
        | "AWAITING_LISTING"
        | "REJECTED"
        | "SUSPENDED"
        | "RENTED"
        | "SOLD"
      property_type_enum: "LAND" | "HOUSE" | "BUILDING"
      proximity_unit_enum: "KM" | "METERS" | "MINUTES_WALK" | "MINUTES_DRIVE"
      rent_status_enum:
        | "DUE"
        | "PAID"
        | "PARTIALLY_PAID"
        | "OVERDUE"
        | "CANCELLED"
      rental_application_status_enum:
        | "SUBMITTED"
        | "REVIEW_IN_PROGRESS"
        | "AWAITING_LANDLORD_CONTACT"
        | "LANDLORD_INFO_PENDING"
        | "LANDLORD_APPROVED"
        | "LANDLORD_REJECTED"
        | "DOCUMENTS_REQUESTED"
        | "DOCUMENTS_VERIFIED"
        | "APPROVED_AWAITING_PAYMENT"
        | "PAYMENT_CONFIRMED"
        | "LEASE_FINALIZED"
        | "TENANCY_ACTIVE"
        | "APPLICATION_WITHDRAWN_CUSTOMER"
        | "CANCELLED_ADMIN"
      service_category_enum:
        | "MAINTENANCE"
        | "REPAIR"
        | "CONSTRUCTION"
        | "DESIGN"
        | "CLEANING"
        | "SECURITY"
        | "LANDSCAPING"
        | "POOL"
        | "PEST_CONTROL"
        | "UTILITIES"
        | "OTHER"
      sms_status_enum: "NOT_SENT" | "SENT" | "FAILED"
      sms_type_enum:
        | "POST_SUBMITTED"
        | "MARKETING_ASSIGNED_TO_MARKETER"
        | "MARKETING_ASSIGNED_TO_CUSTOMER"
        | "MARKETING_REASSIGNED_TO_CUSTOMER"
        | "RENT_APPROVAL_TO_CUSTOMER"
        | "RENTED_APPROVAL_TO_OWNER"
        | "TICKET_CREATED"
        | "TICKET_CLOSED"
        | "CREDITS_PURCHASED"
        | "RENT_DUE"
        | "VISIT_BOOKING_TO_OWNER"
        | "VISIT_BOOKING_TO_TENANT"
        | "TICKET_ASSIGNED_TO_VENDOR"
        | "TICKET_VENDOR_DETAILS_TO_RAISER"
      submitter_type_enum: "OWNER" | "BUILDER" | "AGENT"
      ticket_category_enum:
        | "MAINTENANCE_REPAIR"
        | "PLUMBING"
        | "ELECTRICAL"
        | "APPLIANCE"
        | "CLEANING"
        | "LANDSCAPING"
        | "PEST_CONTROL"
        | "NOISE_COMPLAINT"
        | "LEASE_QUERY"
        | "PAYMENT_QUERY"
        | "GENERAL_INQUIRY"
        | "OTHER"
      ticket_priority_enum: "LOW" | "MEDIUM" | "HIGH"
      ticket_status_enum:
        | "NEW"
        | "OPEN"
        | "ASSIGNED"
        | "WAITING_TENANT_RESPONSE"
        | "WAITING_OWNER_RESPONSE"
        | "IN_PROGRESS"
        | "RESOLVED"
        | "CLOSED"
        | "CANCELLED"
      vendor_status_enum: "ACTIVE" | "INACTIVE" | "UNDER_REVIEW"
      water_source_enum: "BOREWELL" | "MUNICIPAL" | "BOTH"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      admin_role_enum: [
        "super-admin",
        "telecalling-owner-team",
        "marketing-team",
        "telecalling-tenant-team",
        "sales-team",
        "accounts-team",
      ],
      area_unit_enum: ["SQ_FT", "CENTS", "ACRES"],
      availability_status_enum: ["UNDER_CONSTRUCTION", "READY_TO_MOVE"],
      building_type_enum: [
        "OFFICE",
        "WAREHOUSE",
        "RETAIL",
        "INDUSTRIAL",
        "HOSPITALITY",
      ],
      direction_enum: ["NORTH", "SOUTH", "EAST", "WEST"],
      furnished_status_enum: [
        "UNFURNISHED",
        "SEMI_FURNISHED",
        "FULLY_FURNISHED",
      ],
      house_type_enum: ["APARTMENT_FLAT", "INDEPENDENT_VILLA", "HOSTEL_PG"],
      interaction_status_enum: [
        "WISHLISTED",
        "VISIT_PENDING",
        "VISIT_CONFIRMED_PENDING_SALES",
        "VISIT_SCHEDULED_WITH_SALES",
        "VISIT_COMPLETED",
        "VISIT_CANCELLED",
        "RENTAL_APPLICATION_SUBMITTED",
        "LEASE_CONVERTED",
      ],
      land_type_enum: ["RESIDENTIAL", "COMMERCIAL", "AGRICULTURAL"],
      listing_type_enum: ["RENTAL", "SALE"],
      power_backup_enum: ["NONE", "PARTIAL", "FULL"],
      property_admin_status_enum: [
        "SUBMITTED",
        "OWNER_CONTACT_PENDING",
        "OWNER_VERIFIED",
        "MARKETING_VISIT_PENDING",
        "MARKETING_VERIFIED",
        "AWAITING_LISTING",
        "REJECTED",
        "SUSPENDED",
        "RENTED",
        "SOLD",
      ],
      property_type_enum: ["LAND", "HOUSE", "BUILDING"],
      proximity_unit_enum: ["KM", "METERS", "MINUTES_WALK", "MINUTES_DRIVE"],
      rent_status_enum: [
        "DUE",
        "PAID",
        "PARTIALLY_PAID",
        "OVERDUE",
        "CANCELLED",
      ],
      rental_application_status_enum: [
        "SUBMITTED",
        "REVIEW_IN_PROGRESS",
        "AWAITING_LANDLORD_CONTACT",
        "LANDLORD_INFO_PENDING",
        "LANDLORD_APPROVED",
        "LANDLORD_REJECTED",
        "DOCUMENTS_REQUESTED",
        "DOCUMENTS_VERIFIED",
        "APPROVED_AWAITING_PAYMENT",
        "PAYMENT_CONFIRMED",
        "LEASE_FINALIZED",
        "TENANCY_ACTIVE",
        "APPLICATION_WITHDRAWN_CUSTOMER",
        "CANCELLED_ADMIN",
      ],
      service_category_enum: [
        "MAINTENANCE",
        "REPAIR",
        "CONSTRUCTION",
        "DESIGN",
        "CLEANING",
        "SECURITY",
        "LANDSCAPING",
        "POOL",
        "PEST_CONTROL",
        "UTILITIES",
        "OTHER",
      ],
      sms_status_enum: ["NOT_SENT", "SENT", "FAILED"],
      sms_type_enum: [
        "POST_SUBMITTED",
        "MARKETING_ASSIGNED_TO_MARKETER",
        "MARKETING_ASSIGNED_TO_CUSTOMER",
        "MARKETING_REASSIGNED_TO_CUSTOMER",
        "RENT_APPROVAL_TO_CUSTOMER",
        "RENTED_APPROVAL_TO_OWNER",
        "TICKET_CREATED",
        "TICKET_CLOSED",
        "CREDITS_PURCHASED",
        "RENT_DUE",
        "VISIT_BOOKING_TO_OWNER",
        "VISIT_BOOKING_TO_TENANT",
        "TICKET_ASSIGNED_TO_VENDOR",
        "TICKET_VENDOR_DETAILS_TO_RAISER",
      ],
      submitter_type_enum: ["OWNER", "BUILDER", "AGENT"],
      ticket_category_enum: [
        "MAINTENANCE_REPAIR",
        "PLUMBING",
        "ELECTRICAL",
        "APPLIANCE",
        "CLEANING",
        "LANDSCAPING",
        "PEST_CONTROL",
        "NOISE_COMPLAINT",
        "LEASE_QUERY",
        "PAYMENT_QUERY",
        "GENERAL_INQUIRY",
        "OTHER",
      ],
      ticket_priority_enum: ["LOW", "MEDIUM", "HIGH"],
      ticket_status_enum: [
        "NEW",
        "OPEN",
        "ASSIGNED",
        "WAITING_TENANT_RESPONSE",
        "WAITING_OWNER_RESPONSE",
        "IN_PROGRESS",
        "RESOLVED",
        "CLOSED",
        "CANCELLED",
      ],
      vendor_status_enum: ["ACTIVE", "INACTIVE", "UNDER_REVIEW"],
      water_source_enum: ["BOREWELL", "MUNICIPAL", "BOTH"],
    },
  },
} as const
