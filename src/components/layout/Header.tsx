
import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '@/context/AuthContext';
import { useStyleSettings } from '@/hooks/useStyleSettings';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

const Header = () => {
  const location = useLocation();
  const { user, logout } = useAuth();
  const { isWindows98Style } = useStyleSettings();

  // Updated navigation items - removed KPiR from menu
  const getNavItems = () => {
    const baseItems = [];

    // Dokumenty - dla wszystkich zalogowanych użytkowników
    baseItems.push({ 
      name: 'Dokumenty', 
      path: '/dokumenty',
      icon: '/lovable-uploads/88a736db-1198-4c92-b31a-d8b7c4c8adb7.png'
    });

    // Pozostałe pozycje dla wszystkich zalogowanych użytkowników
    baseItems.push(
      { 
        name: 'Raporty', 
        path: '/reports',
        icon: '/lovable-uploads/021f933f-b354-4042-b593-acbe82f67257.png'
      },
      { 
        name: 'Ustawienia', 
        path: '/settings',
        icon: '/lovable-uploads/ef42a7e5-53d2-4c0a-8208-6e4863ef2f82.png'
      }
    );

    // Administracja dla prowincjała i admina
    if (user?.role === 'prowincjal' || user?.role === 'admin') {
      baseItems.push({ 
        name: 'Administracja', 
        path: '/administracja',
        icon: '/lovable-uploads/ef42a7e5-53d2-4c0a-8208-6e4863ef2f82.png' // używam tej samej ikony co dla ustawień
      });
    }

    return baseItems;
  };

  const navItems = getNavItems();

  // Zwracanie inicjału imienia użytkownika
  const getInitial = () => {
    if (user?.name) {
      return user.name.charAt(0).toUpperCase();
    }
    if (user?.email) {
      return user.email.charAt(0).toUpperCase();
    }
    return '?';
  };

  return (
    <header className="bg-white border-b border-gray-200">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex h-16 justify-between">
          <div className="flex items-center">
            <Link to="/" className="flex-shrink-0 flex items-center">
              <img
                className="h-8 w-auto"
                src="/placeholder.svg"
                alt="Logo OMI"
              />
              <span className="ml-2 text-lg font-semibold text-omi-500">
                Finanse OMI
              </span>
            </Link>
            
            {/* Menu nawigacyjne */}
            {user && (
              <nav className="hidden md:ml-6 md:flex md:space-x-4">
                {navItems.map((item) => (
                  <Link
                    key={item.name}
                    to={item.path}
                    className={`inline-flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors
                    ${
                      location.pathname === item.path
                        ? 'text-omi-600 bg-gray-100'
                        : 'text-gray-700 hover:bg-gray-100 hover:text-gray-900'
                    }`}
                    title={item.name}
                  >
                    {isWindows98Style ? (
                      <img 
                        src={item.icon} 
                        alt={item.name}
                        className="w-6 h-6"
                      />
                    ) : (
                      item.name
                    )}
                  </Link>
                ))}
              </nav>
            )}
          </div>
          
          {/* Przyciski z prawej */}
          <div className="flex items-center">
            {user ? (
              <div className="flex items-center ml-4 md:ml-6">
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon" className="rounded-full">
                      <Avatar className="h-8 w-8">
                        <AvatarFallback className="bg-omi-300 text-white">
                          {getInitial()}
                        </AvatarFallback>
                      </Avatar>
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuLabel>Moje konto</DropdownMenuLabel>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem onClick={() => logout()}>
                      Wyloguj
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            ) : (
              <Link to="/login">
                <Button variant="default" size="sm">
                  Logowanie
                </Button>
              </Link>
            )}
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;
