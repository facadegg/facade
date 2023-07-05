import * as React from 'react'

import Header from './Header'
import styled from "styled-components";

const Content = styled.div`
  align-items: center;
  display: flex;
  flex-direction: column;
  min-height: 100%;
  width: 100%;
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
