// Import modules
import React from 'react'
import ReactDOM from 'react-dom'
import faker from 'faker'
import SmartDataTable from '..'
import Web3 from 'web3'
import OTCButlerJSON from '../build/contracts/ERC20OptionTrade.json'

const sematicUI = {
  segment: 'ui basic segment',
  message: 'ui message',
  input: 'ui icon input',
  searchIcon: 'search icon',
  rowsIcon: 'numbered list icon',
  table: 'ui compact selectable table',
  select: 'ui dropdown',
  refresh: 'ui labeled primary icon button',
  refreshIcon: 'sync alternate icon',
  change: 'ui labeled secondary icon button',
  changeIcon: 'exchange icon',
  checkbox: 'ui toggle checkbox',
  loader: 'ui active text loader',
  deleteIcon: 'trash red icon',
}

class AppDemo extends React.Component {
  constructor(props) {
    super(props)

    this.state = {
      data: [],
      filterValue: '',
      account: '',
    }

    this.onFilterChanged = this.onFilterChanged.bind(this)
    this.listenTo = this.listenTo.bind(this)
  }

  componentDidMount() {
    window.addEventListener('load', async () => {
      // Modern dapp browsers...
      if (window.ethereum) {
        window.web3 = new Web3(ethereum);
        try {
          // Request account access if needed
          await ethereum.enable();
          console.log('Metamask Active!');
        } catch (error) {
          console.log(error);
        }
      }
      // Legacy dapp browsers...
      else if (window.web3) {
        window.web3 = new Web3(web3.currentProvider);
        console.log('Old');
      }
      // Non-dapp browsers...
      else {
        console.log('Non-Ethereum browser detected. You should consider trying MetaMask!');
      }
      console.log(window.web3);
      let otcButler = new window.web3.eth.Contract(OTCButlerJSON.abi, '0x889950991b414bc84efe9512a6f1b51e6292fd26');
      let accounts = await window.web3.eth.getAccounts();
      this.setState({account: accounts[0]})
      console.log(this.state.account);

      console.log('Start listeners...');
      this.listen(otcButler.events.OpenTrade({fromBlock: 0}));
      this.listen(otcButler.events.UpdateTrade({fromBlock: 0}));
      console.log('Started listeners.');
    });
  }

  listenTo(event) {
      console.log(event);
      if (event.returnValues.buyer == this.state.account || event.returnValues.seller == this.state.account
          || event.returnValues.buyer == '0x0000000000000000000000000000000000000000' 
          || event.returnValues.seller == '0x0000000000000000000000000000000000000000') {
        const trade = event.returnValues;
        this.setState(state => {
          const list = state.data.concat({
            id: trade.tradeId,
            buyer: trade.buyer,
            seller: trade.seller,
            token: trade.symbol,
            amount: trade.amountOfTokens,
            price: trade.pricePerToken,
            payment: trade.amountOfTokens * trade.pricePerToken,
            depositPercentage: trade.depositPercentage,
            deposit: trade.amountOfTokens * trade.pricePerToken * trade.depositPercentage / 100,
            expiration: trade.expiration,
            state: trade.state,
          });
          return {data: list};
        });
      }
    }

  listen(emitter) {
    emitter.on('data', this.listenTo)
    .on('changed', function(event) {
      console.log("Changed!!!");
    }).on('error', console.log);
  }


  getHeaders() {
    return {
      id: {
        text: 'Trade ID',
      },
      buyer: {
        text:'Buyer',
      },
      seller: {
        text: 'Seller',
      },
      token: {
        text: 'Token',
      },
      amount: {
        text: 'Amount of Tokens',
      },
      price: {
        text: 'Price per Token',
      },
      payment: {
        text: 'Total Payment', // amount * price
      },
      depositPercentage: {
        text: 'Deposit percentage',
      },
      deposit: {
        text: 'Total Deposit', // payment * depositPercentage / 100
      },
      state: {
        text: 'Trade State',
        transform: (value, idx, row) => (
          value == 1 ? `OPEN_SELL` :
          value == 2 ? `OPEN_BUY` :
          value == 3 ? `CANCELLED` :
          value == 4 ? `MATCHED` :
          value == 5 ? `CLOSED` :
          value == 6 ? `EXPIRED` :
          'NONE' )
      },
    }
  }

  onFilterChanged({ target: { name, value } }) {
    this.setState({ filterValue: value })
  }

  render() {
    const { data, filterValue, account } = this.state
    const headers = this.getHeaders()
    return (
      <div>
        <div className={sematicUI.segment}>
          <div className={sematicUI.input}>
            <input type='text' value={filterValue} 
              placeholder='Search trades...' onChange={this.onFilterChanged} />
            <i className={sematicUI.searchIcon} />
          </div>
        </div>
        <SmartDataTable
          data={data.filter(trade => trade.buyer == account)}
          dataKey=''
          headers={headers}
          name='test-table'
          className={sematicUI.table}
          filterValue={filterValue}
          sortable
          withHeader
          loader={(
            <div className={sematicUI.loader}>
              Loading...
            </div>
          )}
          dynamic
          emptyTable={(
            <div className={sematicUI.message}>
              There is no data available to display.
            </div>
          )}
        />
          <div className={sematicUI.message}>
            <p> Found {data.length} trades.</p>
          </div>
      </div>
    )
  }
}


ReactDOM.render(
  <AppDemo />,
  document.getElementById('app'),
)
