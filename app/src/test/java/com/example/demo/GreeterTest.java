package com.example.demo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import org.junit.jupiter.api.Test;

public class GreeterTest {
    @Test
    void greetReturnsExpectedMessage() {
        // To demo a failing build live, change the expected string below
        // and let students watch the pipeline go red.
        assertEquals("Hello from the CI/CD demo pipeline!", Greeter.greet());
    }
}
