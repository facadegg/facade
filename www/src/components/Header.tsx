import * as React from "react"

const headerStyle: React.CSSProperties = {
    borderBottom: "0.5px solid rgba(255, 255, 255, 0.12)",
    display: 'flex',
    gap: 14,
    margin: '0 21px 0 21px',
    padding: '16px 0 16px 0',
    position: 'fixed',
    width: 'calc(100% - 42px)',
}

const headerGapStyle: React.CSSProperties = {
    height: "calc(42px + 5rem)",
}

const SiteIcon: React.FC<{}> = React.memo(() => {
    return (
        <img
            alt="Facade Logo"
            src="data:image/svg+xml,%3Csvg width='30' height='16' viewBox='0 0 30 16' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M29.6354 2.64434C29.1857 2.07384 26.7156 -0.47006 19.7284 2.04696C18.3658 2.75176 16.0502 3.83911 14.9964 3.73841C13.9292 3.83239 11.627 2.75176 10.2711 2.04696C3.29059 -0.463341 0.820559 2.0604 0.357425 2.64434C-0.284447 8.97435 2.72257 17.7312 7.9286 14.2562C9.14348 13.4508 10.4054 12.699 11.7008 12.0345C13.7949 10.9539 16.1911 10.9539 18.2853 12.0345C19.5807 12.699 20.8493 13.4441 22.0642 14.2562C27.1724 17.6659 30.3183 9.3157 29.6354 2.64434ZM8.39845 10.0343C6.22375 10.0343 4.47188 7.55086 4.47188 7.55086C4.47188 7.55086 6.22375 5.06071 8.39845 5.06071C10.5664 5.06071 12.325 7.55086 12.325 7.55086C12.325 7.55086 10.5664 10.0343 8.39845 10.0343ZM21.6011 10.0343C19.4264 10.0343 17.6745 7.55086 17.6745 7.55086C17.6745 7.55086 19.4264 5.06071 21.6011 5.06071C23.769 5.06071 25.5276 7.55086 25.5276 7.55086C25.5276 7.55086 23.769 10.0343 21.6011 10.0343Z' fill='white'/%3E
%3C/svg%3E"
        />
    )
})

const Header: React.FC<{}> = () => {
    return (
        <>
            <header style={headerStyle}>
                <SiteIcon />
                <span>Facade</span>
            </header>
            <div style={headerGapStyle} />
        </>
    )
}

export default Header
