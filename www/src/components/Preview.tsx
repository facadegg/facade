import * as React from 'react'
import bryanGreynolds from '../images/preview/Bryan_Greynolds.png'
import zackReal from '../images/zack/real.jpg'
import zackAsTimChrys from '../images/zack/Zack-As-Tim-Chrys.png'
import styled from "styled-components";

const chromeStyle: React.CSSProperties = {
    aspectRatio: '902 / 728',
    backgroundColor: 'rgba(39, 41, 43, .87)',
    borderRadius: 12,
    display: 'flex',
    flexDirection: 'column',
    maxHeight: '80%',
    maxWidth: 'min(80%, 902px)',
    height: '80%',
}

const appBarStyle: React.CSSProperties = {
    display: 'flex',
    gap: '.88%',
    padding: '.88%',
}

const appBarButtonStyle: React.CSSProperties = {
    aspectRatio: '1 / 1',
    borderRadius: '50%',
    width: '1.55%',
}

const cameraPanelStyle: React.CSSProperties = {
    textAlign: 'center',
    paddingBottom: 16,
    paddingTop: 8,
}

const cameraFeedStyle: React.CSSProperties = {
    aspectRatio: '493 / 227',
    borderRadius: 12,
    width: "54.65%",
}

const faceChooserPanelStyle: React.CSSProperties = {
    display: 'flex',
    flexGrow: 1,
    flexWrap: 'wrap',
    overflowY: 'scroll',
    padding: 32,
}

const FaceChoice = styled.div`
  font-size: 12px;
  text-align: center;
  width: 20%;
  
  > img {
    aspect-ratio: 86 / 126;
    width: 53.84%;
  }
`

const Preview: React.FC<{}> = React.memo(() => {
    return (
        <div style={chromeStyle}>
            <div style={appBarStyle}>
                <div style={{ backgroundColor: '#DA4453', ...appBarButtonStyle }} />
                <div style={{ backgroundColor: '#F9BF3B', ...appBarButtonStyle }} />
                <div style={{ backgroundColor: '#66BB6A', ...appBarButtonStyle }} />
            </div>
            <div style={cameraPanelStyle}>
                <img alt="Zack Gemmell" src={zackAsTimChrys} style={cameraFeedStyle} />
            </div>
            <div style={faceChooserPanelStyle}>
                <FaceChoice>
                    <img alt="Bryan Greynolds" src={bryanGreynolds} />
                    <p>Bryan Greynolds</p>
                </FaceChoice>
                <FaceChoice>
                    <img alt="Bryan Greynolds" src={bryanGreynolds} />
                    <p>David Kovalniy</p>
                </FaceChoice>
                <FaceChoice>
                    <img alt="Bryan Greynolds" src={bryanGreynolds} />
                    <p>Ewon Spice</p>
                </FaceChoice>
                <FaceChoice>
                    <img alt="Bryan Greynolds" src={bryanGreynolds} />
                    <p>Kim Jarrey</p>
                </FaceChoice>
                <FaceChoice>
                    <img alt="Bryan Greynolds" src={bryanGreynolds} />
                    <p>Tim Chrys</p>
                </FaceChoice>
                <FaceChoice>
                    <img alt="Bryan Greynolds" src={bryanGreynolds} />
                    <p>Tim Norland</p>
                </FaceChoice>
                <FaceChoice>
                    <img alt="Bryan Greynolds" src={bryanGreynolds} />
                    <p>Zahar Lupin</p>
                </FaceChoice>
            </div>
        </div>
    )
})

export default Preview
