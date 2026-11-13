const { setTimeout: delay } = require('node:timers/promises');

async function runReservationTransaction(db, update) {
  for (let attempt = 0; ; attempt++) {
    try {
      return await db.runTransaction(update);
    } catch (error) {
      // Retry transient contention/transport failures; never retry validation errors.
      // The transaction re-reads the reservation, making an uncertain commit safe.
      if (error.status || ![4, 10, 14].includes(error.code) || attempt >= 2) throw error;
      await delay(100 * (2 ** attempt) + Math.floor(Math.random() * 100));
    }
  }
}
module.exports = { runReservationTransaction };
