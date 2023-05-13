import * as React from "react"
import type { HeadFC, PageProps } from "gatsby"
import Page from '../components/Page'
import Preview from '../components/Preview'
import styled from "styled-components";

const Title = styled.h1`
  font-size: 6rem;
  font-weight: normal;
  margin-bottom: 0;
`

const TagLine = styled.p`
  font-size: 1.5rem;
  margin-bottom: 4rem;
`

const IndexPage: React.FC<PageProps> = () => {
  return (
    <Page>
        <Title>Facade</Title>
        <TagLine>The virtual camera that reimagines reality</TagLine>
        <Preview />
    </Page>
  )
}

export default IndexPage

export const Head: HeadFC = () => <title>Facade − A way to reimagine reality</title>
