import Link from "next/link"

import { siteConfig } from "@/config/site"
import { Icons } from "@/components/icons"
import { MainNav } from "@/components/main-nav"
import { ThemeToggle } from "@/components/theme-toggle"
import { buttonVariants } from "@/components/ui/button"
import {  Network } from "lucide-react"
import { getLoginUrl } from '@/lib/auth'
import { Button } from "@/components/ui/button"

const REDIRECT_URI =
  process.env.NEXT_PUBLIC_REDIRECT_URI || 'http://localhost:3000';

export function SiteHeader() {

  function signInWithGoogle() {
    // Get login url
    const loginUrl = getLoginUrl(REDIRECT_URI)
    // Redirect to login url
    window.location.assign(loginUrl);
  }

  
  return (
    <header className="sticky top-0 z-40 w-full border-b border-b-slate-200 bg-white dark:border-b-slate-700 dark:bg-slate-900">
      <div className="container flex h-16 items-center space-x-4 sm:justify-between sm:space-x-0">
        <MainNav items={siteConfig.mainNav} />
        <div className="flex flex-1 items-center justify-end space-x-4">
          <nav className="flex items-center space-x-1">
            <Button onClick={signInWithGoogle}>
      <Network className="mr-2 h-4 w-4" /> Connect 
    </Button>
            <ThemeToggle />
          </nav>
        </div>
      </div>
    </header>
  )
}
