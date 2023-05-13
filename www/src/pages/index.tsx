import * as React from "react"
import type { HeadFC, PageProps } from "gatsby"
import Page from '../components/Page'
import Preview from '../components/Preview'
import styled from "styled-components";

const Pill = styled.div`   
  background: rgba(255, 255, 255, 0.17);
  backdrop-filter: blur(24px);
  border: 1px solid rgba(255, 255, 255, 0.17);
  border-radius: 24px;
  padding: 8px 12px 8px 12px;
`

const Title = styled.h1`
  font-size: 6rem;
  font-weight: normal;
  margin-top: 1rem;
  margin-bottom: 0;
`

const TagLine = styled.p`
  font-size: 1.5rem;
  font-weight: lighter;
  margin-bottom: 4rem;
  max-width: 60%;
  text-align: center;
`

const IndexPage: React.FC<PageProps> = () => {
  return (
    <Page>
        <Pill>Get on the wait list →</Pill>
        <Title>Reimagine Reality</Title>
        <TagLine>
            Facade gives your camera the capabilities to
            reimagine how you present yourself.
        </TagLine>
        <Preview />
    </Page>
  )
}

export default IndexPage

export const Head: HeadFC = () => <title>Facade − A way to reimagine reality</title>
