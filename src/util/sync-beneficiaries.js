import { baseApiUrl } from '@stssocialst-stp/fe-core';

const SYNC_URL = `${baseApiUrl}/payroll/beneficiarios/sincronizar/`;
const GRAPHQL_URL = `${baseApiUrl}/graphql`;

const POLL_INTERVAL_MS = 2500;
// A sincronização corre em background e pode demorar minutos (ex.: ~6000 grupos).
const POLL_TIMEOUT_MS = 30 * 60 * 1000; // 30 minutos

const sleep = (ms) => new Promise((resolve) => { setTimeout(resolve, ms); });

/**
 * POST do pedido de sincronização. Devolve a Response ou null em caso de erro de rede.
 */
async function requestSync(benefitPlanId) {
  try {
    return await fetch(SYNC_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ benefit_plan: benefitPlanId }),
    });
  } catch {
    return null;
  }
}

async function fetchMutationStatus(clientMutationId) {
  const response = await fetch(GRAPHQL_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'same-origin',
    body: JSON.stringify({
      query: `query ($clientMutationId: String) {
        mutationLogs(clientMutationId: $clientMutationId) {
          edges { node { status error jsonExt clientMutationLabel } }
        }
      }`,
      variables: { clientMutationId },
    }),
  });
  const payload = await response.json();
  return payload?.data?.mutationLogs?.edges?.[0]?.node ?? null;
}

async function pollMutation(clientMutationId) {
  const startedAt = Date.now();

  while (Date.now() - startedAt < POLL_TIMEOUT_MS) {
    // eslint-disable-next-line no-await-in-loop
    await sleep(POLL_INTERVAL_MS);

    let node = null;
    try {
      // eslint-disable-next-line no-await-in-loop
      node = await fetchMutationStatus(clientMutationId);
    } catch {
      node = null; // falha de rede transitória: continua a fazer poll
    }

    if (node) {
      if (node.status === 2) {
        return { ok: true, node };
      }
      if (node.status === 1) {
        return {
          ok: false,
          node,
          message: typeof node.error === 'string' ? node.error : null,
        };
      }
    }
  }

  return {
    ok: false, node: null, message: null, timedOut: true,
  };
}

/**
 * Dispara a sincronização de beneficiários de um Benefit Plan do tipo GROUP.
 *   POST {baseApiUrl}/payroll/beneficiarios/sincronizar/  { benefit_plan }
 * Resposta 202 { clientMutationId } e, depois, poll a mutationLogs até status 2 (sucesso)
 * ou 1 (erro).
 */
export default async function sincronizarBeneficiarios(benefitPlanId) {
  const response = await requestSync(benefitPlanId);
  if (!response) {
    return { ok: false, status: null, message: null };
  }

  const contentType = response.headers.get('content-type') || '';
  const data = contentType.includes('application/json')
    ? await response.json().catch(() => null)
    : null;

  if (!response.ok) {
    return {
      ok: false,
      status: response.status,
      message: data?.message || null,
    };
  }

  const clientMutationId = data?.clientMutationId;
  if (!clientMutationId) {
    return { ok: false, status: response.status, message: null };
  }

  const pollResult = await pollMutation(clientMutationId);
  if (pollResult.ok) {
    return {
      ok: true,
      node: pollResult.node,
      output: pollResult.node?.jsonExt?.output ?? null,
    };
  }

  return {
    ok: false,
    status: response.status,
    message: pollResult.message,
    node: pollResult.node,
    timedOut: pollResult.timedOut,
  };
}
