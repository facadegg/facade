import * as React from 'react'
import styled from "styled-components";

import bryanGreynolds from '../images/preview/Bryan_Greynolds.png'
import zackAsTimChrys from '../images/zack/Zack-As-Tim-Chrys.png'

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

const Chrome = styled.div`
  aspect-ratio: 902 / 728;
  background-color: rgba(39, 41, 43, .87);
  border-radius: 1.76%;
  box-shadow: 0 2px 12px 1px rgba(0, 0, 0, .33);
  display: flex;
  flex-direction: column;
  max-height: 80%;
  max-width: min(80%, 902px);
  height: 80%;
  transition: opacity 0.5s linear;
`

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

const Tile = styled.div`
  display: grid;
  grid-template-rows: 48px 48px;
  grid-template-columns: 48px 48px;
  
  left: calc(50% - 48px);
  position: absolute;
  top: 0;
  
  height: 96px;
  width: 96px;

  &> .spinner {
    height: 48px;
    width: 48px;
  }
`

const PreviewLayout = styled.div`
  display: flex;
  height: 100%;
  justify-content: center;
  position: relative;
  width: 100%;
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

const PreviewIcon: React.FC<{}> = React.memo(() => (
    <Tile>
        <div className="spinner spinner-1" style={{ gridRow: 1, gridColumn: 1 }} />
        <div className="spinner spinner-1" style={{ gridRow: 1, gridColumn: 2 }}  />
        <div className="spinner spinner-1" style={{ gridRow: 2, gridColumn: 1 }} />
        <div className="spinner spinner-1" style={{ gridRow: 2, gridColumn: 2 }} />
    </Tile>
))

const PreviewApplication: React.FC<{
    hide: boolean
    onImageLoad: () => void
}> = React.memo(({ hide, onImageLoad }) => (
    <Chrome style={hide ? {opacity: 0} : {opacity: 1}}>
        <div style={appBarStyle}>
            <div style={{ backgroundColor: '#DA4453', ...appBarButtonStyle }} />
            <div style={{ backgroundColor: '#F9BF3B', ...appBarButtonStyle }} />
            <div style={{ backgroundColor: '#66BB6A', ...appBarButtonStyle }} />
        </div>
        <div style={cameraPanelStyle}>
            <img
                alt="Zack Gemmell"
                loading="lazy"
                onError={onImageLoad}
                onLoad={onImageLoad}
                src={zackAsTimChrys}
                style={cameraFeedStyle}
            />
        </div>
        <div style={faceChooserPanelStyle}>
            {Object.entries(CHOICES).map(([name, image]) => (
                <FaceChoice key={name} tabIndex={0}>
                    <img alt={name} onError={onImageLoad} onLoad={onImageLoad} loading="lazy" src={image} />
                    <p>{name.replace('_', ' ')}</p>
                </FaceChoice>
            ))}
        </div>
    </Chrome>
))

const Preview: React.FC<{}> = React.memo(() => {
    const [client, setClient] = React.useState(false);
    const [loadCount, setLoadCount] = React.useState(0)
    const loaded = React.useMemo(() => loadCount >= 1 + new Set(Object.values(CHOICES)).size, [loadCount])

    const onImageLoad = React.useCallback(() => {
        console.log('hERE')
        setLoadCount(n => n + 1)
    }, []);

    React.useEffect(() => {
        if (typeof window !== 'undefined')
            setClient(true)
    }, []);

    return (
        <PreviewLayout>
            {!loaded && <PreviewIcon />}
            {client && <PreviewApplication hide={!loaded} onImageLoad={onImageLoad} />}
        </PreviewLayout>
    )
})

export default Preview
