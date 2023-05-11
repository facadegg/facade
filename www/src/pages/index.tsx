import * as React from "react"
import type { HeadFC, PageProps } from "gatsby"
import Page from '../components/Page'
import Preview from '../components/Preview'

const IndexPage: React.FC<PageProps> = () => {
  return (
    <Page>
      <Preview />
    </Page>
  )
}

export default IndexPage

export const Head: HeadFC = () => <title>Home Page</title>
