import * as React from "react"
import type { HeadFC, PageProps } from "gatsby"
import Page from '../components/Page'
import Preview from '../components/Preview'
import styled from "styled-components";
import DownloadOnTheMacAppStore from '../images/Download_on_the_Mac_App_Store_Badge_US-UK_RGB_blk_092917.svg'

const Pill = styled.div`   
  background: rgba(255, 255, 255, 0.17);
  backdrop-filter: blur(24px);
  border: 1px solid rgba(255, 255, 255, 0.17);
  border-radius: 24px;
  padding: 8px 12px 8px 12px;
`

const Title = styled.h1`
  font-size: 3rem;
  font-weight: normal;
  margin-top: 1rem;
  margin-bottom: 0;
  
  @media(min-width: 768px) {
    font-size: 6rem;
  }
`

const TagLine = styled.p`
  font-size: 1.5rem;
  font-weight: lighter;
  text-align: center;
  white-space: break-spaces;
  
  @media(min-width: 768px) {
    max-width: 60%;
  }
`

const Spacing = styled.div`
  margin-bottom: 4rem;
`

const Box = styled.div`
  align-items: center;
  background-image: linear-gradient(-22.5deg, #1d2121 0%, #000000 74%);
  display: flex;
  flex-direction: column;
  padding: calc(42px + 4rem) 0 10rem 0;
  margin: 0;
  width: 100%;

  @media (min-width: 768px) {
    padding-top: calc(42px + 5rem);
  }
`

const IndexPage: React.FC<PageProps> = () => {
  return (
    <Page>
        <Box>
            <Title>Reimagine Reality</Title>
            <TagLine>
                Facade gives your camera the capabilities to
                reimagine how you present yourself.
            </TagLine>
            <Spacing />
            <a href="https://www.youtube.com/watch?v=dQw4w9WgXcQ" target="_blank">
                <img src={DownloadOnTheMacAppStore} alt="Download on the Mac App Store" />
            </a>
            <Spacing />
            <Preview />
        </Box>
    </Page>
  )
}

export default IndexPage

export const Head: HeadFC = () => <title>Facade − A way to reimagine reality</title>
