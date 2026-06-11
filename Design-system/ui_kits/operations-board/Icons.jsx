/* Line icons — Lucide stroke style (1.5px, rounded). Single-color via currentColor.
   These are the only icons used in the kit; emoji are explicitly out. */

const Icon = ({ children, size = 18, ...rest }) => (
  <svg
    width={size} height={size} viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth="1.5"
    strokeLinecap="round" strokeLinejoin="round"
    {...rest}
  >{children}</svg>
);

const IconHome      = (p) => <Icon {...p}><path d="M3 12l9-9 9 9"/><path d="M5 10v11h5v-7h4v7h5V10"/></Icon>;
const IconCatalog   = (p) => <Icon {...p}><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></Icon>;
const IconList      = (p) => <Icon {...p}><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/></Icon>;
const IconBoard     = (p) => <Icon {...p}><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/><circle cx="7" cy="14" r="1" fill="currentColor"/><path d="M11 14h7"/></Icon>;

const IconLaptop    = (p) => <Icon {...p}><rect x="3" y="5" width="18" height="11" rx="1.5"/><path d="M2 20h20"/></Icon>;
const IconApp       = (p) => <Icon {...p}><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18"/><circle cx="6.5" cy="6.5" r="0.6" fill="currentColor"/><circle cx="9" cy="6.5" r="0.6" fill="currentColor"/></Icon>;
const IconCloud     = (p) => <Icon {...p}><path d="M17 18a4 4 0 0 0 0-8 6 6 0 0 0-11.7 1.5A4.5 4.5 0 0 0 6.5 18z"/></Icon>;
const IconWrench    = (p) => <Icon {...p}><path d="M14.7 6.3a4 4 0 0 0 5.7 5.7l-9.4 9.4a2 2 0 0 1-2.8-2.8z"/><path d="M17 7l-2-2"/></Icon>;
const IconBag       = (p) => <Icon {...p}><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"/><path d="M3 6h18"/><path d="M16 10a4 4 0 0 1-8 0"/></Icon>;
const IconRefresh   = (p) => <Icon {...p}><path d="M21 12a9 9 0 1 1-3-6.7L21 8"/><path d="M21 3v5h-5"/></Icon>;
const IconBuilding  = (p) => <Icon {...p}><rect x="4" y="2" width="16" height="20" rx="1.5"/><path d="M9 22v-4h6v4"/><path d="M8 6h.01M16 6h.01M8 10h.01M16 10h.01M8 14h.01M16 14h.01M12 6h.01M12 10h.01M12 14h.01"/></Icon>;
const IconZap       = (p) => <Icon {...p}><path d="M13 2L4 14h7l-1 8 9-12h-7z"/></Icon>;

const IconPenLine   = (p) => <Icon {...p}><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/></Icon>;
const IconEye       = (p) => <Icon {...p}><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/></Icon>;
const IconSiren     = (p) => <Icon {...p}><path d="M7 12a5 5 0 0 1 10 0v6H7z"/><path d="M5 20h14"/><path d="M21 12h1M2 12h1M12 2v1M19 5l.7-.7M5 5l-.7-.7"/></Icon>;
const IconPackage   = (p) => <Icon {...p}><path d="M12 3l9 4.5v9L12 21l-9-4.5v-9z"/><path d="M3 7.5l9 4.5 9-4.5"/><path d="M12 12v9"/></Icon>;
const IconCheck     = (p) => <Icon {...p}><circle cx="12" cy="12" r="9"/><path d="M8 12l3 3 5-6"/></Icon>;
const IconInbox     = (p) => <Icon {...p}><path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/></Icon>;
const IconRotateCw  = (p) => <Icon {...p}><path d="M21 12a9 9 0 1 1-3-6.7"/><path d="M21 4v5h-5"/></Icon>;
const IconX         = (p) => <Icon {...p}><path d="M18 6L6 18M6 6l12 12"/></Icon>;
const IconChev      = (p) => <Icon {...p}><path d="M9 6l6 6-6 6"/></Icon>;
const IconChevDown  = (p) => <Icon {...p}><path d="M6 9l6 6 6-6"/></Icon>;
const IconArrowLeft = (p) => <Icon {...p}><path d="M19 12H5M12 19l-7-7 7-7"/></Icon>;
const IconMinus     = (p) => <Icon {...p}><path d="M5 12h14"/></Icon>;
const IconPlus      = (p) => <Icon {...p}><path d="M12 5v14M5 12h14"/></Icon>;

Object.assign(window, {
  Icon,
  IconHome, IconCatalog, IconList, IconBoard,
  IconLaptop, IconApp, IconCloud, IconWrench,
  IconBag, IconRefresh, IconBuilding, IconZap,
  IconPenLine, IconEye, IconSiren, IconPackage,
  IconCheck, IconInbox, IconRotateCw, IconX,
  IconChev, IconChevDown, IconArrowLeft, IconMinus, IconPlus,
});
