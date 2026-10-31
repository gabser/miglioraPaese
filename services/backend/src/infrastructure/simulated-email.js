// Private dependency-injected local adapter. Never mounted as an HTTP endpoint.
export function createSimulatedEmailAdapter() {
  const outbox=[];
  return {
    delivery:'simulated',
    async deliver(message) {outbox.push(structuredClone(message));},
    // Exposed only to the in-process test/fixture owner, not the application API.
    inspect:()=>structuredClone(outbox),
    clear:()=>{outbox.length=0;},
  };
}
