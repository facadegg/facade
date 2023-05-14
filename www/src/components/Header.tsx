import * as React from "react"
import styled from "styled-components";

import SiteIcon from "./SiteIcon";

const headerGapStyle: React.CSSProperties = {
    height: "calc(42px + 5rem)",
}

const HeaderBackdrop = styled.div`
  background: rgba(0, 0, 0, .5);
  backdrop-filter: blur(48px);
  display: flex;
  justify-content: center;
  padding: 0;
  position: fixed;
  width: 100%;
  z-index: 1;

  -webkit-backdrop-filter: blur(48px);
`

const HeaderLayout = styled.div`
  background: rgba(0, 0, 0, 0);
  border-bottom: 0.5px solid rgba(255, 255, 255, 0.12); 
  display: flex;
  gap: 14px;
  margin: 0 48px 0 48px;
  max-width: 902px;
  padding: 16px 0 16px 0;
  width: calc(100% - 96px);
`;

const Header: React.FC<{}> = () => {
    return (
        <>
            <HeaderBackdrop>
                <HeaderLayout>
                    <SiteIcon />
                    <span>Facade</span>
                </HeaderLayout>
            </HeaderBackdrop>
            <div style={headerGapStyle} />
        </>
    )
}

export default Header
