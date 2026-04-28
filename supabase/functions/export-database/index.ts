import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.9'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface DatabaseTable {
  table_name: string;
  data: any[];
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Verify user is admin
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('No authorization header');
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );

    if (authError || !user) {
      throw new Error('Unauthorized');
    }

    // Check if user is admin
    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (!profile || profile.role !== 'admin') {
      throw new Error('Admin role required');
    }

    console.log('Starting database export...');

    // Pełna lista tabel w kolejności zależności (rodzice przed dziećmi).
 // Tabele bez FK są dodane na końcu - kolejność dla nich nie ma znaczenia.
    const tablesToExport = [
      // Słowniki/podstawowe
      'locations',
      'location_settings',
      'accounts',
      'location_accounts',
      'profiles',
      'user_locations',
      'user_settings',
      'analytical_accounts',
      // Dokumenty i transakcje
      'documents',
      'transactions',
      // Raporty
      'reports',
      'report_details',
      'report_account_details',
      'report_sections',
      'report_entries',
      // Mapowania i ograniczenia
      'account_section_mappings',
      'account_category_restrictions',
      // Budżety
      'budget_categories',
      'budget_category_mappings',
      'budget_plans',
      'budget_items',
      // Opłaty prowincjalne
      'provincial_fee_accounts',
      'provincial_fee_settings',
      // Kalendarz, notatki, baza wiedzy
      'calendar_events',
      'admin_notes',
      'knowledge_documents',
      // Powiadomienia, logi, błędy
      'notifications',
      'reminder_logs',
      'error_reports',
      'error_report_responses',
      'user_login_events',
      'failed_logins',
      // Ustawienia aplikacji i features
      'app_settings',
      'project_features',
      // Bezpieczeństwo / sesje
      'trusted_devices',
      'verification_codes',
      'password_reset_tokens',
      // Kursy walut
      'exchange_rate_history',
    ];

    const exportData: { 
      timestamp: string;
      tables: DatabaseTable[];
      metadata: {
        exportedBy: string;
        totalTables: number;
        totalRecords: number;
      }
    } = {
      timestamp: new Date().toISOString(),
      tables: [],
      metadata: {
        exportedBy: user.email || user.id,
        totalTables: 0,
        totalRecords: 0
      }
    };

    let totalRecords = 0;

    // Export each table - z paginacją (limit Supabase 1000 wierszy/zapytanie)
    const PAGE_SIZE = 1000;
    for (const tableName of tablesToExport) {
      try {
        console.log(`Exporting table: ${tableName}`);
        const allRows: any[] = [];
        let from = 0;
        // Pobieraj strony aż do wyczerpania danych
        // eslint-disable-next-line no-constant-condition
        while (true) {
          const { data, error } = await supabase
            .from(tableName)
            .select('*')
            .range(from, from + PAGE_SIZE - 1);

          if (error) {
            console.error(`Error exporting ${tableName} (page from ${from}):`, error);
            break;
          }
          if (!data || data.length === 0) break;
          allRows.push(...data);
          if (data.length < PAGE_SIZE) break;
          from += PAGE_SIZE;
        }

        if (allRows.length > 0) {
          exportData.tables.push({
            table_name: tableName,
            data: allRows
          });
          totalRecords += allRows.length;
          console.log(`Exported ${allRows.length} records from ${tableName}`);
        } else {
          // Zapisz pustą tabelę żeby było wiadomo że została sprawdzona
          exportData.tables.push({
            table_name: tableName,
            data: []
          });
          console.log(`Table ${tableName} is empty`);
        }
      } catch (tableError) {
        console.error(`Failed to export table ${tableName}:`, tableError);
      }
    }

    exportData.metadata.totalTables = exportData.tables.length;
    exportData.metadata.totalRecords = totalRecords;

    console.log(`Database export completed. Tables: ${exportData.metadata.totalTables}, Records: ${totalRecords}`);

    return new Response(
      JSON.stringify(exportData),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );

  } catch (error) {
    console.error('Export database error:', error);
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Failed to export database' 
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});