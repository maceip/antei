import { NavItem } from "@/types/nav"

interface SiteConfig {
  name: string
  description: string
  mainNav: NavItem[]
  links: {
    twitter: string
    github: string
    docs: string
  }
}

export const siteConfig: SiteConfig = {
  name: "安定",
  description:
    "Unlocking Liquidity!",
  mainNav: [
    {
      title: "Home",
      href: "/",
    },
  ],
  links: {
    twitter: "https://twitter.com/maceip",
    github: "https://github.com/maceip/antei",
    docs: "https://github.com/maceip/antei/tree/master/contracs",
  },
}
