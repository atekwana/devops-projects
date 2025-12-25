package com.visualpathit.account.serviceTest;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.mockito.ArgumentMatchers.any;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.MockitoJUnitRunner;

import com.visualpathit.account.model.User;
import com.visualpathit.account.repository.RoleRepository;
import com.visualpathit.account.repository.UserRepository;
import com.visualpathit.account.service.UserService;

@RunWith(MockitoJUnitRunner.class)
public class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    @SuppressWarnings("unused")
    private RoleRepository roleRepository;

    @InjectMocks
    private UserService userService;

    private User testUser;

    @Before
    public void setup() {
        testUser = new User();
        testUser.setId(1L);
        testUser.setUsername("testuser");
        testUser.setPassword("password");
    }

    @Test
    public void testSaveUser() {
        when(userRepository.save(any(User.class))).thenReturn(testUser);
        userService.save(testUser);
        verify(userRepository, times(1)).save(testUser);
    }

    @Test
    public void testFindByUsername() {
        when(userRepository.findByUsername("testuser")).thenReturn(testUser);
        User result = userService.findByUsername("testuser");
        assertNotNull(result);
        assertEquals("testuser", result.getUsername());
    }
}
