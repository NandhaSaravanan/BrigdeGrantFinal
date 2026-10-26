/**
 * Build-time configuration from Vite environment variables.
 *
 * Only the Supabase project URL and the publishable (anon) key belong here.
 * Never use a service-role or `sb_secret_` key in the website.
 */
export interface AppConfig {
  supabaseUrl: string
  supabaseKey: string
}

export function readConfig(env: Record<string, string | undefined> = import.meta.env): AppConfig {
  return {
    supabaseUrl: (env.VITE_SUPABASE_URL ?? '').trim(),
    supabaseKey: (env.VITE_SUPABASE_ANON_KEY ?? '').trim(),
  }
}

/** Detects secret keys so a misconfigured build refuses to run with one. */
export function looksLikeServiceRoleKey(key: string): boolean {
  if (key.startsWith('sb_secret_')) return true
  const parts = key.split('.')
  if (parts.length !== 3) return false
  try {
    const json = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'))
    return /"role"\s*:\s*"service_role"/.test(json)
  } catch {
    return false
  }
}

/** Returns a human-readable configuration problem, or null. */
export function configProblem(config: AppConfig): string | null {
  if (!config.supabaseUrl || !config.supabaseKey) {
    return 'VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY must be set.'
  }
  try {
    const url = new URL(config.supabaseUrl)
    if (url.protocol !== 'https:' && url.hostname !== 'localhost') {
      return 'VITE_SUPABASE_URL must use https.'
    }
  } catch {
    return 'VITE_SUPABASE_URL is not a valid URL.'
  }
  if (looksLikeServiceRoleKey(config.supabaseKey)) {
    return 'The key looks like a service-role/secret key. Use the publishable (anon) key.'
  }
  return null
}
