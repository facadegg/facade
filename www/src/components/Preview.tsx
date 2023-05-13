import * as React from 'react'
import bryanGreynolds from '../images/preview/Bryan_Greynolds.png'
import zackReal from '../images/zack/real.jpg'
import zackAsTimChrys from '../images/zack/Zack-As-Tim-Chrys.png'
import styled from "styled-components";

const chromeStyle: React.CSSProperties = {
    aspectRatio: '902 / 728',
    backgroundColor: 'rgba(39, 41, 43, .87)',
    borderRadius: '1.76%',
    boxShadow: '0 2px 12px 1px rgba(0, 0, 0, .33)',
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
    padding: 32,
}

const FaceChoice = styled.div`
  font-size: 12px;
  margin-bottom: 4%;
  text-align: center;
  width: 20%;
  
  &> img {
    aspect-ratio: 86 / 126;
    width: 53.84%;
  }
  
  &>p {
    margin-top: 8px;
    margin-bottom: 0;
  }
 
  &:focus {
    outline: none;
  }
  
  &:focus > img {
    border-radius: 8px;
    box-shadow: 0 0 100px 4px #ABFFC633;
    outline: 3px solid #ABFFC6;
  }
`

const CHOICES = {
    'Bryan_Greynolds': bryanGreynolds,
    'David_Kovalniy': bryanGreynolds,
    'Ewon_Spice': bryanGreynolds,
    'Kim_Jarrey': bryanGreynolds,
    'Tim_Chrys': bryanGreynolds,
    'Tim_Norland': bryanGreynolds,
    'Zahar_Lupin': bryanGreynolds,
} as const

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
                {Object.entries(CHOICES).map(([name, image]) => (
                    <FaceChoice id={name} tabIndex={0}>
                        <img alt={name} src={image} />
                        <p>{name.replace('_', ' ')}</p>
                    </FaceChoice>
                ))}
            </div>
        </div>
    )
})

export default Preview
