#include "unity.h"
#include <stdbool.h>
#include <stdlib.h>
#include "../../examples/autotest-validate/autotest-validate.h"
#include "../../assignment-autotest/test/assignment1/username-from-conf-file.h"

void test_validate_my_username(void)
{
    const char *username = my_username();
    char *conf_username = malloc_username_from_conf_file();

    TEST_ASSERT_NOT_NULL_MESSAGE(
        conf_username,
        "Failed to read username from /conf/username.txt"
    );

    TEST_ASSERT_EQUAL_STRING_MESSAGE(
        conf_username,
        username,
        "my_username() must match /conf/username.txt"
    );

    free(conf_username);
}