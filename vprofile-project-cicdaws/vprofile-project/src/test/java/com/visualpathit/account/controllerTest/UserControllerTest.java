package com.visualpathit.account.controllerTest;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.forwardedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.view;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import com.visualpathit.account.controller.UserController;
import com.visualpathit.account.service.UserService;
import com.visualpathit.account.setup.StandaloneMvcTestViewResolver;

// ADDED: Use MockitoJUnitRunner instead of MockitoAnnotations.initMocks() (deprecated)
@RunWith(MockitoJUnitRunner.class)
public class UserControllerTest {

    @Mock
    private UserService controllerSer;

    @InjectMocks
    private UserController controller;

    private MockMvc mockMvc;

    @Before
    public void setup() {
        // REMOVED: MockitoAnnotations.initMocks(this) - deprecated and unnecessary with @RunWith
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setViewResolvers(new StandaloneMvcTestViewResolver()).build();
    }

    @Test
    public void registrationTestforHappyFlow() throws Exception {
        mockMvc.perform(get("/registration"))
                .andExpect(status().isOk())
                .andExpect(view().name("registration"))
                .andExpect(forwardedUrl("registration"));
    }

    // REMOVED: registrationTestforNullValueHappyFlow() - this is a DUPLICATE test (exact same as above)
    // This was causing the "duplicated lines" error in SonarQube

    @Test
    public void loginTestHappyFlow() throws Exception {
        mockMvc.perform(get("/"))
                .andExpect(status().isOk())
                .andExpect(view().name("login"))
                .andExpect(forwardedUrl("login"));
    }

    @Test
    public void welcomeTestHappyFlow() throws Exception {
        mockMvc.perform(get("/welcome"))
                .andExpect(status().isOk())
                .andExpect(view().name("welcome"))
                .andExpect(forwardedUrl("welcome"));
    }

    // REMOVED: welcomeAfterDirectLoginTestHappyFlow() - this is a DUPLICATE test (exact same as loginTestHappyFlow)
    // This was also causing duplicated lines error

    @Test
    public void indexTestHappyFlow() throws Exception {
        mockMvc.perform(get("/index"))
                .andExpect(status().isOk())
                .andExpect(view().name("index_home"))
                .andExpect(forwardedUrl("index_home"));
    }
}