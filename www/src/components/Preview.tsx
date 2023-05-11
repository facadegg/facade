import * as React from 'react'

const chromeStyle = {
    backgroundColor: '#27292b',
    borderRadius: '8px',
    height: '400px',
    width: '80%',
}

const Preview: React.FC<{}> = React.memo(() => {
    return (
        <div style={chromeStyle}>

        </div>
    )
})

export default Preview
