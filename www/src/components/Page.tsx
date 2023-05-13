import * as React from 'react'

import Header from './Header'
import styled from "styled-components";

const Content = styled.div`
  align-items: center;
  display: flex;
  flex-direction: column;
  height: 100%;
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
