import * as React from 'react'
import styled from "styled-components";

import bryanGreynolds from '../images/preview/Bryan_Greynolds.png'

const CameraPanel = styled.div`
  flex-grow: 1;
  text-align: center;
  min-width: 0;
  min-height: 0;
  height: 100%;

  @media (min-width: 1024px) {
    padding: 2rem;
  }
`

const CameraFeed = styled.video`
  aspect-ratio: 1920 / 1080;
  border-radius: 12px;
  max-height: 360px;
  max-width: 480px;
  width: 100%;
`

const Chrome = styled.div`
  border-radius: 1.76%;
  display: flex;
  flex-direction: column;
  max-width: min(80vw, 902px);
  padding: 2em 1em 0 1em;
  transition: opacity 0.5s linear;

  @media (min-width: 1024px) {
    align-items: center;
    flex-direction: row;
    max-height: 900px;
    max-width: min(67em, 100vw);
    min-height: 0;
    height: fit-content;
    padding: 1em 0 1em 0;
    width: fit-content;
  }
`

const FaceChooserPanel = styled.div`
  display: flex;
  gap: 18px;

  @media (max-width: 1024px) {
    flex-direction: row;
    min-height: calc(6.45rem + 1rem);
    overflow-x: scroll;
    padding-top: 2em;
  }
  
  @media (min-width: 1024px) {
    flex-wrap: wrap;
    padding: 0 32px 0 32px;
    max-height: 400px;
    flex-basis: 484px;
  }
`

const FaceChoice = styled.div`
  font-size: 12px;
  text-align: center;
  min-width: 6.45rem;
  margin-bottom: 0;
  height: fit-content;
  
  &> img {
    aspect-ratio: 86 / 126;
    max-height: 140px;
    max-width: 95.55px;
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
  
  @media (min-width: 1024px) {
    flex-basis: 20%;

    &:first-child {
      margin-bottom: 1em;
    }
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

type Face = keyof typeof CHOICES | 'Anna_Tolipova'

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
}> = React.memo(({ hide, onImageLoad }) => {
    const [face, setFace] = React.useState<Face>('Anna_Tolipova')
    const faceFeedRef = React.useRef<HTMLVideoElement | null>(null)

    const onFocusFace = React.useMemo(() => Object.fromEntries(
        Object.keys(CHOICES).map((face) => [
            face,
            () => {
                const pos = faceFeedRef.current!.currentTime
                console.log(pos)
                setFace(face as keyof typeof CHOICES)

                faceFeedRef.current!.addEventListener('canplaythrough',  function listener() {
                    console.log('here', faceFeedRef.current!.currentTime)
                    faceFeedRef.current!.currentTime = pos
                    faceFeedRef.current!.play().finally(console.log)
                    faceFeedRef.current!.removeEventListener('canplaythrough', listener)
                })
            }
        ])
    ), [])

    return (
        <Chrome style={hide ? {opacity: 0} : {opacity: 1}}>
            <CameraPanel>
                <CameraFeed
                    autoPlay={true}
                    loop={true}
                    ref={faceFeedRef}
                    src={`https://r2.facade.gg/samples/man-talking-video-call-living-room/${face}.mp4`}
                />
            </CameraPanel>
            <FaceChooserPanel>
                {Object.entries(CHOICES).map(([name, image]) => (
                    <FaceChoice key={name} onFocus={onFocusFace[name]} tabIndex={0}>
                        <img alt={name} onError={onImageLoad} onLoad={onImageLoad} src={image} />
                        <p>{name.replace('_', ' ')}</p>
                    </FaceChoice>
                ))}
            </FaceChooserPanel>
        </Chrome>
    )
})

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
