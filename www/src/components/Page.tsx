import * as React from 'react'

import Header from './Header'
import styled from "styled-components";

const Content = styled.div`
  display: flex;
  height: 100%;
  justify-content: center;
  padding: 96px;
  width: 100%;
  
  @media (max-width: 1440px) {
    padding: 32px;
  }
`

const Page: React.FC<React.PropsWithChildren<{}>> = ({ children }) => {
    return (
        <>
            <Header />
            <Content>
                {children}
            </Content>
        </>
    )
}

export default Page
