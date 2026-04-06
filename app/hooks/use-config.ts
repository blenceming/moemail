"use client"

import { create } from "zustand"
import { Role, ROLES } from "@/lib/permissions"
import { EMAIL_CONFIG } from "@/config"
import { useEffect } from "react"
import { parseEmailDomains, stringifyEmailDomains } from "@/lib/email-domains"

interface Config {
  defaultRole: Exclude<Role, typeof ROLES.EMPEROR>
  emailDomains: string
  emailDomainsArray: string[]
  adminContact: string
  maxEmails: number
}

interface ConfigStore {
  config: Config | null
  loading: boolean
  error: string | null
  fetch: () => Promise<void>
}

const useConfigStore = create<ConfigStore>((set) => ({
  config: null,
  loading: false,
  error: null,
  fetch: async () => {
    try {
      set({ loading: true, error: null })
      const res = await fetch("/api/config", { cache: "no-store" })
      if (!res.ok) throw new Error("获取配置失败")
      const data = await res.json() as Config
      const emailDomains = stringifyEmailDomains(data.emailDomains)
      set({
        config: {
          defaultRole: data.defaultRole || ROLES.CIVILIAN,
          emailDomains,
          emailDomainsArray: parseEmailDomains(emailDomains),
          adminContact: data.adminContact || "",
          maxEmails: Number(data.maxEmails) || EMAIL_CONFIG.MAX_ACTIVE_EMAILS
        },
        loading: false
      })
    } catch (error) {
      set({ 
        error: error instanceof Error ? error.message : "获取配置失败",
        loading: false 
      })
    }
  }
}))

export function useConfig() {
  const store = useConfigStore()

  useEffect(() => {
    if (!store.config && !store.loading) {
      store.fetch()
    }
  }, [store.config, store.loading])

  return store
}
