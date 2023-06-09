import Link from "next/link"

import { siteConfig } from "@/config/site"
import { Layout } from "@/components/layout"
import { buttonVariants } from "@/components/ui/button"
import Head from 'next/head';
import Image from 'next/image';
import { Inter } from 'next/font/google';
import { useCallback, useEffect, useState } from 'react';
import { LitNodeClient } from '@lit-protocol/lit-node-client';
import { ethers } from 'ethers';
import {
  getLoginUrl,
  isSignInRedirect,
  handleSignInRedirect,
} from '@/lib/auth';
import {
  fetchPKPs,
  mintPKP,
  pollRequestUntilTerminalState,
} from '@/lib/relay';
import { useRouter } from 'next/router';
import { providers } from "ethers";
import { Aggregator, BlsWalletWrapper, getConfig } from "bls-wallet-clients";
import {
  UiPoolDataProvider,
  UiIncentiveDataProvider,
  ChainId,
  GhoService,
} from '@aave/contract-helpers';
import {
  formatGhoReserveData,
  formatGhoUserData,
  formatReservesAndIncentives,
  formatUserSummaryAndIncentives,
} from '@aave/math-utils';



const REDIRECT_URI =
  process.env.NEXT_PUBLIC_REDIRECT_URI || 'http://localhost:3000';

const Views = {
  SIGN_IN: 'sign_in',
  FETCHING: 'fetching',
  FETCHED: 'fetched',
  MINTING: 'minting',
  MINTED: 'minted',
  CREATING_SESSION: 'creating_session',
  SESSION_CREATED: 'session_created',
  ERROR: 'error',
};


export default function IndexPage() {
const router = useRouter();
const [view, setView] = useState(Views.SIGN_IN);
const [error, setError] = useState();

const [litNodeClient, setLitNodeClient] = useState();
const [googleIdToken, setGoogleIdToken] = useState();
const [pkps, setPKPs] = useState([]);
const [currentPKP, setCurrentPKP] = useState();
const [sessionSigs, setSessionSigs] = useState();

const [message, setMessage] = useState('Free the web!');
const [signature, setSignature] = useState(null);
const [recoveredAddress, setRecoveredAddress] = useState(null);
const [verified, setVerified] = useState(false);



// Sample RPC address for querying ETH goerli
const provider = new ethers.providers.JsonRpcProvider(
  'https://eth-goerli.public.blastapi.io',
);

// User address to fetch data for, insert address here
const currentAccount = '0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c';

// View contract used to fetch all reserves data (including market base currency data), and user reserves
// Using Aave V3 Eth goerli address for demo
const poolDataProviderContract = new UiPoolDataProvider({
  uiPoolDataProviderAddress: '0x3De59b6901e7Ad0A19621D49C5b52cC9a4977e52', // Goerli GHO Market
  provider,
  chainId: ChainId.goerli,
});
const currentTimestamp =  Date.now();

// View contract used to fetch all reserve incentives (APRs), and user incentives
// Using Aave V3 Eth goerli address for demo
const incentiveDataProviderContract = new UiIncentiveDataProvider({
  uiIncentiveDataProviderAddress:
    '0xF67B25977cEFf3563BF7F24A531D6CEAe6870a9d', // Goerli GHO Market
  provider,
  chainId: ChainId.goerli,
});

const ghoService = new GhoService({
    provider,
    uiGhoDataProviderAddress: '0xE914D574975a1Cd273388035Db4413dda788c0E5', // Goerli GHO Market
});

async function fetchContractData() {
  // Object containing array of pool reserves and market base currency data
  // { reservesArray, baseCurrencyData }
  const reserves = await poolDataProviderContract.getReservesHumanized({
    lendingPoolAddressProvider: '0x4dd5ab8Fb385F2e12aDe435ba7AFA812F1d364D0', // Goerli GHO Market
  });

  // Object containing array or users aave positions and active eMode category
  // { userReserves, userEmodeCategoryId }
  const userReserves = await poolDataProviderContract.getUserReservesHumanized({
    lendingPoolAddressProvider: '0x4dd5ab8Fb385F2e12aDe435ba7AFA812F1d364D0', // Goerli GHO Market
    user: currentAccount,
  });

  // Array of incentive tokens with price feed and emission APR
  const reserveIncentives =
    await incentiveDataProviderContract.getReservesIncentivesDataHumanized({
      lendingPoolAddressProvider: '0x4dd5ab8Fb385F2e12aDe435ba7AFA812F1d364D0', // Goerli GHO Market
    });

  // Dictionary of claimable user incentives
  const userIncentives =
    await incentiveDataProviderContract.getUserReservesIncentivesDataHumanized({
      lendingPoolAddressProvider: '0x4dd5ab8Fb385F2e12aDe435ba7AFA812F1d364D0', // Goerli GHO Market
      user: currentAccount,
    });

   const ghoReserveData = await ghoService.getGhoReserveData();
   const ghoUserData = await ghoService.getGhoUserData(currentAccount);

  const formattedGhoReserveData = formatGhoReserveData({
    ghoReserveData,
  });
  const formattedGhoUserData = formatGhoUserData({
    ghoReserveData,
    ghoUserData,
    currentTimestamp,
  });

  const formattedPoolReserves = formatReservesAndIncentives({
    reserves: reserves.reservesData,
    currentTimestamp,
    marketReferenceCurrencyDecimals: reserves.baseCurrencyData.marketReferenceCurrencyDecimals,
    marketReferencePriceInUsd: reserves.baseCurrencyData.marketReferenceCurrencyPriceInUsd,
    reserveIncentives: reserveIncentives,
  })

  const userSummary = formatUserSummaryAndIncentives({
    currentTimestamp,
    marketReferencePriceInUsd: reserves.baseCurrencyData.marketReferenceCurrencyPriceInUsd,
    marketReferenceCurrencyDecimals: reserves.baseCurrencyData.marketReferenceCurrencyDecimals,
    userReserves: userReserves.userReserves,
    formattedReserves: formattedPoolReserves,
    userEmodeCategoryId: userReserves.userEmodeCategoryId,
    reserveIncentives: reserveIncentives,
    userIncentives: userIncentives,
  });

let formattedUserSummary = userSummary;
  // Factor discounted GHO interest into cumulative user fields
  if (formattedGhoUserData.userDiscountedGhoInterest > 0) {
    const userSummaryWithDiscount = formatUserSummaryWithDiscount({
      userGhoDiscountedInterest: formattedGhoUserData.userDiscountedGhoInterest,
      user,
      marketReferenceCurrencyPriceUSD: Number(
        formatUnits(reserves.baseCurrencyData.marketReferenceCurrencyPriceInUsd, USD_DECIMALS)
      ),
    });
    formattedUserSummary = {
      ...userSummary,
      ...userSummaryWithDiscount,
    };
  }

   console.log({ formattedGhoReserveData, formattedGhoUserData, formattedPoolReserves, formattedUserSummary });
}

fetchContractData();


const handleRedirect = useCallback(async () => {
  setView(Views.HANDLE_REDIRECT);
  try {
    // Get Google ID token from redirect callback
    const googleIdToken = handleSignInRedirect(REDIRECT_URI);
    setGoogleIdToken(googleIdToken);

    // Fetch PKPs associated with Google account
    setView(Views.FETCHING);
    const pkps = await fetchGooglePKPs(googleIdToken);
    if (pkps.length > 0) {
      setPKPs(pkps);
    }
    setView(Views.FETCHED);
  } catch (err) {
    setError(err);
    setView(Views.ERROR);
  }

  // Clear url params once we have the Google ID token
  // Be sure to use the redirect uri route
  router.replace('/', undefined, { shallow: true });
}, [router]);

/**
 * Mint a new PKP for the authorized Google account
 */
async function mint() {
  setView(Views.MINTING);

  try {
    // Mint new PKP
    const newPKP = await mintGooglePKP(googleIdToken);

    // Add new PKP to list of PKPs
    const morePKPs = pkps.push(newPKP);
    setPKPs(morePKPs);

    setView(Views.MINTED);
    setView(Views.CREATING_SESSION);

    // Get session sigs for new PKP
    await createSession(newPKP);
  } catch (err) {
    setError(err);
    setView(Views.ERROR);
  }
}

/**
 * Generate session sigs for current PKP
 *
 * @param {Object} PKP - PKP object
 */
async function createSession(pkp) {
  setView(Views.CREATING_SESSION);

  try {
    // Connect to LitNodeClient if not already connected
    if (!litNodeClient.ready) {
      await litNodeClient.connect();
    }

    const authNeededCallback = async authCallbackParams => {
      let chainId = 1;
      try {
        const chainInfo = ALL_LIT_CHAINS[authCallbackParams.chain];
        chainId = chainInfo.chainId;
      } catch {
        // Do nothing
      }

      let response = await litNodeClient.signSessionKey({
        authMethods: [
          {
            authMethodType: 6,
            accessToken: googleIdToken,
          },
        ],
        pkpPublicKey: pkp.publicKey,
        expiration: authCallbackParams.expiration,
        resources: authCallbackParams.resources,
        chainId,
      });

      return response.authSig;
    };

    // Generate session sigs with the given session params
    const sessionSigs = await litNodeClient.getSessionSigs({
      chain: 'ethereum',
      resources: [`litAction://*`],
      authNeededCallback,
    });

    setCurrentPKP(pkp);
    setSessionSigs(sessionSigs);

    setView(Views.SESSION_CREATED);
  } catch (err) {
    setError(err);
    setView(Views.ERROR);
  }
}

/**
 * Sign a message with current PKP
 */
async function signMessage() {
  try {
    const toSign = ethers.utils.arrayify(ethers.utils.hashMessage(message));
    const litActionCode = `
      const go = async () => {
        // this requests a signature share from the Lit Node
        // the signature share will be automatically returned in the response from the node
        // and combined into a full signature by the LitJsSdk for you to use on the client
        // all the params (toSign, publicKey, sigName) are passed in from the LitJsSdk.executeJs() function
        const sigShare = await LitActions.signEcdsa({ toSign, publicKey, sigName });
      };
      go();
    `;
    // Sign message
    const results = await litNodeClient.executeJs({
      code: litActionCode,
      sessionSigs,
      jsParams: {
        toSign: toSign,
        publicKey: currentPKP.publicKey,
        sigName: 'sig1',
      },
    });
    // Get signature
    const result = results.signatures['sig1'];
    const signature = ethers.utils.joinSignature({
      r: '0x' + result.r,
      s: '0x' + result.s,
      v: result.recid,
    });
    setSignature(signature);

    // Get the address associated with the signature created by signing the message
    const recoveredAddr = ethers.utils.verifyMessage(message, signature);
    setRecoveredAddress(recoveredAddr);
    // Check if the address associated with the signature is the same as the current PKP
    const verified =
      currentPKP.ethAddress.toLowerCase() === recoveredAddr.toLowerCase();
    setVerified(verified);
  } catch (err) {
    setError(err);
    setView(Views.ERROR);
  }
}

useEffect(() => {
  /**
   * Initialize LitNodeClient
   */
  async function initLitNodeClient() {
    try {
      // Set up LitNodeClient
      const litNodeClient = new LitNodeClient({
        litNetwork: 'serrano',
        debug: false,
      });

      // Connect to Lit nodes
      await litNodeClient.connect();

      // Set LitNodeClient
      setLitNodeClient(litNodeClient);
    } catch (err) {
      setError(err);
      setView(Views.ERROR);
    }
  }

  if (!litNodeClient) {
    initLitNodeClient();
  }
}, [litNodeClient]);

useEffect(() => {
  // Check if app has been redirected from Lit login server
  if (isSignInRedirect(REDIRECT_URI)) {
    handleRedirect();
  }
}, [handleRedirect]);


  return (
    <Layout>
      <Head>
        <title>Eth Tokto</title>
        <meta
          name="description"
          content="Universal liquidity for all your wallets and chains"
        />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="icon" href="/favicon.ico" />
      </Head>
      <section className="container grid items-center gap-6 pt-6 pb-8 md:py-10">
        <div className="flex max-w-[980px] flex-col items-start gap-2">
          <h1 className="text-3xl font-extrabold leading-tight tracking-tighter sm:text-3xl md:text-5xl lg:text-6xl">
            antei: trustless liquid vaults <br className="hidden sm:inline" />
            safely leverage your assets universally
          </h1>
          <p className="max-w-[700px] text-lg text-slate-700 dark:text-slate-400 sm:text-xl">
            Antei vaults are controlled by a network of erc4332 BLS smart contract wallets, and for every vote-Escorewed or locked tocken you deposit, our network will mint a GHO token
            , leveraging 1inch fusion.
          </p>
        </div>
        <div className="flex gap-4">
          <Link
            href={siteConfig.links.docs}
            target="_blank"
            rel="noreferrer"
            className={buttonVariants({ size: "lg" })}
          >
            Documentation
          </Link>
          <Link
            target="_blank"
            rel="noreferrer"
            href={siteConfig.links.github}
            className={buttonVariants({ variant: "outline", size: "lg" })}
            onClick={console.log()}
          >
            GitHub
          </Link>
        </div>
      </section>
      {view === Views.ERROR && (
          <>
            <h1>Error</h1>
            <p>{error.message}</p>
            <button
              onClick={() => {
                if (sessionSigs) {
                  setView(Views.SESSION_CREATED);
                } else {
                  if (googleIdToken) {
                    setView(Views.FETCHED);
                  } else {
                    setView(Views.SIGN_IN);
                  }
                }
                setError(null);
              }}
            >
              Got it
            </button>
          </>
        )}
        {view === Views.SIGN_IN && (
          <>
{/*handle not authed*/}
          </>
        )}
        {view === Views.HANDLE_REDIRECT && (
          <>
            <h1>Verifying your identity...</h1>
          </>
        )}
        {view === Views.FETCHING && (
          <>
            <h1>Fetching your PKPs...</h1>
          </>
        )}
        {view === Views.FETCHED && (
          <>
            {pkps.length > 0 ? (
              <>
                <h1>Select a PKP to continue</h1>
                {/* Select a PKP to create session sigs for */}
                <div>
                  {pkps.map(pkp => (
                    <button
                      key={pkp.ethAddress}
                      onClick={async () => await createSession(pkp)}
                    >
                      {pkp.ethAddress}
                    </button>
                  ))}
                </div>
                <hr></hr>
                {/* Or mint another PKP */}
                <p>or mint another one:</p>
                <button onClick={mint}>Mint another PKP</button>
              </>
            ) : (
              <>
                <h1>Mint a PKP to continue</h1>
                <button onClick={mint}>Mint a PKP</button>
              </>
            )}
          </>
        )}
        {view === Views.MINTING && (
          <>
            <h1>Minting your PKP...</h1>
          </>
        )}
        {view === Views.MINTED && (
          <>
            <h1>Minted!</h1>
          </>
        )}
        {view === Views.CREATING_SESSION && (
          <>
            <h1>Saving your session...</h1>
          </>
        )}
        {view === Views.SESSION_CREATED && (
          <>
            <h1>Ready for the open web</h1>
            <div>
              <p>Check out your PKP:</p>
              <p>{currentPKP.ethAddress}</p>
            </div>
            <hr></hr>
            <div>
              <p>Sign this message with your PKP:</p>
              <p>{message}</p>
              <button onClick={signMessage}>Sign message</button>

              {signature && (
                <>
                  <h3>Your signature:</h3>
                  <p>{signature}</p>
                  <h3>Recovered address:</h3>
                  <p>{recoveredAddress}</p>
                  <h3>Verified:</h3>
                  <p>{verified ? 'true' : 'false'}</p>
                </>
              )}
            </div>
          </>
        )}
    </Layout>
    
  )
}

/**
 * Redirect user to the Google authorization page
 */
function signInWithGoogle() {
  // Get login url
  const loginUrl = getLoginUrl(REDIRECT_URI);
  // Redirect to login url
  window.location.assign(loginUrl);
}

/**
 * Fetch PKPs associated with the given Google account through the relay server
 *
 * @param {string} idToken - Google ID token
 *
 * @returns PKPs associated with Google account
 */
async function fetchGooglePKPs(idToken) {
  // Fetch PKPs associated with Google OAuth
  const body = JSON.stringify({
    idToken: idToken,
  });
  const fetchRes = await fetchPKPs(body);
  const { pkps } = fetchRes;
  if (!pkps) {
    throw new Error('Unable to fetch PKPs through relay server');
  }
  return pkps;
}

/**
 * Mint a PKP for the given Google account through the relay server
 *
 * @param {string} idToken - Google ID token
 *
 * @returns newly minted PKP
 */
async function mintGooglePKP(idToken) {
  // Mint a new PKP via relay server
  const body = JSON.stringify({
    idToken: idToken,
  });
  const mintRes = await mintPKP(body);
  const { requestId } = mintRes;
  if (!requestId) {
    throw new Error('Unable to mint PKP through relay server');
  }

  // Poll for status of minting PKP
  const pollRes = await pollRequestUntilTerminalState(requestId);
  if (
    !pollRes ||
    !pollRes.pkpTokenId ||
    !pollRes.pkpEthAddress ||
    !pollRes.pkpPublicKey
  ) {
    throw new Error('Missing poll response or new PKP from relay server');
  }
  const newPKP = {
    tokenId: pollRes.pkpTokenId,
    ethAddress: pollRes.pkpEthAddress,
    publicKey: pollRes.pkpPublicKey,
  };
  return newPKP;
}