#include <stdio.h>

typedef struct sqlite3 sqlite3;
#define SQLITE_OK 0
#define SQLITE_OPEN_READWRITE 0x00000002

extern int sqlite3_open_v2(const char *, sqlite3 **, int, const char *);
extern int sqlite3_exec(sqlite3 *, const char *,
                        int (*)(void *, int, char **, char **),
                        void *, char **);
extern int sqlite3_close(sqlite3 *);
extern const char *sqlite3_errmsg(sqlite3 *);
extern void sqlite3_free(void *);

static int try_path(const char *path) {
    sqlite3 *db = NULL;
    int rc = sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, NULL);
    printf("path=%s open rc=%d (%s)\n", path, rc,
           db ? sqlite3_errmsg(db) : "no db");
    if (rc != SQLITE_OK) { if (db) sqlite3_close(db); return 1; }
    char *err = NULL;
    rc = sqlite3_exec(db,
        "UPDATE global SET value='2' WHERE name='task_stack_view_layout_style';",
        NULL, NULL, &err);
    printf("  global rc=%d err=%s\n", rc, err ? err : "(none)");
    if (err) { sqlite3_free(err); err = NULL; }
    rc = sqlite3_exec(db,
        "UPDATE secure SET value='2' WHERE name='task_stack_view_layout_style';",
        NULL, NULL, &err);
    printf("  secure rc=%d err=%s\n", rc, err ? err : "(none)");
    if (err) sqlite3_free(err);
    sqlite3_close(db);
    return 0;
}

int main(void) {
    static const char *paths[] = {
        "/data/data/com.android.providers.settings/databases/settings.db",
        "/data/user/0/com.android.providers.settings/databases/settings.db",
        "/data/user_de/0/com.android.providers.settings/databases/settings.db",
        "/data/data/com.android.providers.settings/databases/settings_global.xml",
    };
    for (unsigned i = 0; i < sizeof(paths)/sizeof(paths[0]); i++)
        if (try_path(paths[i]) == 0) break;
    return 0;
}
