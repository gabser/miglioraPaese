export function up(pgm) {
  pgm.createTable('transactional_recovery_probe', {
    id: { type: 'integer', primaryKey: true },
  });
  if (process.env.MIGRATION_FAILURE_INJECTION === 'enabled') {
    pgm.sql('SELECT missing_failure_injection_function();');
  }
}

export function down(pgm) {
  pgm.dropTable('transactional_recovery_probe');
}
