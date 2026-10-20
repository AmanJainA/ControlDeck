/// Static configuration for the two Supabase projects used by ControlDeck.
///
/// These are public publishable keys intended for client applications.
/// Never place a service_role or secret key in this file.
class SupabaseConfig {
  SupabaseConfig._();

  /// Project 1: ControlDeck authentication, LifeHub, Notes and Interview.
  static const String primaryUrl =
      'https://wrssvnvagpnvlwhnqqta.supabase.co';
  static const String primaryKey =
      'sb_publishable_AEu-JBRYrCLYrVq3VjAtyA_ya5ApyuM';

  /// Project 2: Portfolio and Railways data.
  static const String professionalUrl =
      'https://drcxxbymdonyfjtkiouf.supabase.co';
  static const String professionalKey =
      'sb_publishable_G4oyRa9CfTI80TEMOXU3dA_6NTOipc3';
}
