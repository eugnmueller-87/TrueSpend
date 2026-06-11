/* App — state, routing, glue. Desktop shell. */

const App = () => {
  const [tab,        setTab]        = React.useState('board');
  const [reqType,    setReqType]    = React.useState(null);
  const [success,    setSuccess]    = React.useState(null);
  const [modal,      setModal]      = React.useState(null);
  const [tickets,    setTickets]    = React.useState(BOARD_TICKETS);
  const [openId,     setOpenId]     = React.useState('t3');       // start with Adobe brief open
  const [sectionJump, setSectionJump] = React.useState(null);

  const navigate = (t) => {
    setTab(t); setReqType(null); setSuccess(null); setSectionJump(null);
  };

  const handleOrder = (item) => setModal(item);
  const placeOrder = (item) => {
    setModal(null);
    setSuccess({
      ref: 'TS-2026-' + String(500 + Math.floor(Math.random() * 99)).padStart(4, '0'),
      email: 'eva.mueller@ionos.com',
      item: item.name,
    });
  };

  const startRequest = (type) => { setReqType(type); setTab('request'); };
  const submitRequest = () => {
    setSuccess({
      ref: 'TS-2026-' + String(500 + Math.floor(Math.random() * 99)).padStart(4, '0'),
      email: 'eva.mueller@ionos.com',
      item: null,
    });
    setReqType(null);
  };

  const handleAction = (id) => {
    setTickets(prev => prev.filter(t => t.id !== id));
    setOpenId(curOpen => curOpen === id ? null : curOpen);
  };

  const counts = {
    open: tickets.length,
  };
  const openByStatus = tickets.reduce((acc, t) => {
    acc[t.status] = (acc[t.status] || 0) + 1;
    return acc;
  }, {});

  // Map current tab to a top-bar breadcrumb
  const crumbs = (() => {
    if (success)        return ['Submitted'];
    if (tab === 'board')   return ['Operations'];
    if (tab === 'catalog') return ['Catalog'];
    if (tab === 'mine')    return ['My requests'];
    if (tab === 'home')    return ['Home'];
    if (tab === 'request') return ['New request', FORM_CONFIG[reqType]?.title || 'Request'];
    return ['Operations'];
  })();

  const sidebarTab = tab === 'request' ? 'home' : tab;

  return (
    <div className="app">
      <Sidebar
        tab={sidebarTab}
        onNav={navigate}
        counts={counts}
        openByStatus={openByStatus}
        onJumpSection={(st) => { setTab('board'); setSectionJump(st); }}
      />
      <main className="main">
        <TopBar crumbs={crumbs} />

        {success && <Success result={success} onDone={() => { setSuccess(null); navigate('board'); }} />}

        {!success && tab === 'board'   && <Board tickets={tickets} onAction={handleAction} openId={openId} setOpenId={setOpenId} sectionJump={sectionJump} />}
        {!success && tab === 'catalog' && <Catalog onOrder={handleOrder} />}
        {!success && tab === 'mine'    && <MyOrders />}
        {!success && tab === 'home'    && <Home onCatalog={() => navigate('catalog')} onRequestType={startRequest} />}
        {!success && tab === 'request' && reqType && (
          <RequestForm type={reqType} onBack={() => navigate('home')} onSubmit={submitRequest} />
        )}
      </main>
      {modal && <OrderModal item={modal} onClose={() => setModal(null)} onPlace={placeOrder} />}
    </div>
  );
};

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
