import * as React from 'react'

import Header from './Header'

const contentStyle = {
    height: '100%',
    padding: 96,
    width: '100%',
}

const Page: React.FC<React.PropsWithChildren<{}>> = ({ children }) => {
    return (
        <>
            <Header />
            <main style={contentStyle}>
                {children}
            </main>
        </>
    )
}

export default Page
