const DEFAULT_EMAIL_DOMAIN = "moemail.app"

export function parseEmailDomains(value?: string | null): string[] {
  if (!value) {
    return []
  }

  return value
    .replace(/[\uFF0C\r\n]+/g, ",")
    .split(",")
    .map(domain => domain.trim())
    .filter(Boolean)
}

export function stringifyEmailDomains(value?: string | null): string {
  const domains = parseEmailDomains(value)
  return domains.length > 0 ? domains.join(",") : DEFAULT_EMAIL_DOMAIN
}

export function getEmailDomainsOrDefault(value?: string | null): string[] {
  const domains = parseEmailDomains(value)
  return domains.length > 0 ? domains : [DEFAULT_EMAIL_DOMAIN]
}
